import 'dart:async';

import 'package:feedback_review_app/models/app_user.dart';
import 'package:feedback_review_app/models/item.dart';
import 'package:feedback_review_app/providers/auth_providers.dart';
import 'package:feedback_review_app/providers/item_providers.dart';
import 'package:feedback_review_app/repositories/auth_repository.dart';
import 'package:feedback_review_app/repositories/item_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Auth whose sign-in state the test drives by hand.
class FakeAuthRepository implements AuthRepository {
  final controller = StreamController<User?>.broadcast();

  @override
  Stream<User?> authStateChanges() => controller.stream;

  @override
  Stream<AppUser?> watchUser(String uid) => Stream.value(null);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Records every stream handed out so a test can fail or feed each one.
class FakeItemRepository implements ItemRepository {
  final streams = <StreamController<List<Item>>>[];

  @override
  Stream<List<Item>> watchActiveItems({ItemType? type}) {
    final controller = StreamController<List<Item>>();
    streams.add(controller);
    return controller.stream;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

void main() {
  test(
    'items reload for the next user after a sign-out denied the old listener',
    () async {
      final auth = FakeAuthRepository();
      final items = FakeItemRepository();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          itemRepositoryProvider.overrideWithValue(items),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(auth.controller.close);

      // Providers rebuild on the next event-loop turn after auth changes.
      Future<void> settle() async {
        for (var i = 0; i < 3; i++) {
          await Future<void>.delayed(Duration.zero);
        }
      }

      // The router keeps auth state alive for the whole session; do the same.
      container.listen(signedInUidProvider, (_, _) {}, fireImmediately: true);
      await settle();

      // User A signs in, then a screen starts watching the items.
      auth.controller.add(MockUser(uid: 'a'));
      await settle();
      container.listen(itemsProvider(null), (_, _) {}, fireImmediately: true);
      await settle();
      expect(items.streams, hasLength(1));

      // Sign-out: Firestore then denies the old listener and ends its stream,
      // exactly as seen in the device logs (denied ~0.5s after each sign-out).
      auth.controller.add(null);
      await settle();
      items.streams.first
        ..addError(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          ),
        )
        ..close();
      await settle();

      // User B signs in and the list must load again, without pressing Retry.
      auth.controller.add(MockUser(uid: 'b'));
      await settle();
      expect(items.streams, hasLength(2), reason: 'a fresh query for user B');

      final item = Item(
        id: 'i1',
        title: 'T',
        description: '',
        type: ItemType.task,
        isActive: true,
        createdBy: 'x',
        createdAt: DateTime(2026),
      );
      items.streams.last.add([item]);
      await settle();

      final state = container.read(itemsProvider(null));
      expect(state.hasError, isFalse);
      expect(state.value, [item]);
    },
  );

  test('the type filter resets to All when the user changes', () async {
    final auth = FakeAuthRepository();
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(auth)],
    );
    addTearDown(container.dispose);
    addTearDown(auth.controller.close);

    Future<void> settle() async {
      for (var i = 0; i < 3; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    container.listen(signedInUidProvider, (_, _) {}, fireImmediately: true);
    container.listen(itemTypeFilterProvider, (_, _) {}, fireImmediately: true);
    auth.controller.add(MockUser(uid: 'a'));
    await settle();

    container.read(itemTypeFilterProvider.notifier).select(ItemType.course);
    expect(container.read(itemTypeFilterProvider), ItemType.course);

    auth.controller.add(null);
    await settle();
    auth.controller.add(MockUser(uid: 'b'));
    await settle();

    expect(container.read(itemTypeFilterProvider), isNull);
  });
}
