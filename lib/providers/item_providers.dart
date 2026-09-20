import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/app_exception.dart';
import '../models/item.dart';
import '../repositories/item_repository.dart';
import 'async_action_runner.dart';
import 'auth_providers.dart';
import 'firebase_providers.dart';

final itemRepositoryProvider = Provider<ItemRepository>((ref) {
  return ItemRepository(firestoreService: ref.watch(firestoreServiceProvider));
});

/// Active items, optionally restricted to one type (null = all types).
final itemsProvider = StreamProvider.family<List<Item>, ItemType?>((ref, type) {
  // Signed out: nothing to load, and no query that Firestore would deny.
  if (ref.watch(signedInUidProvider) == null) return Stream.value(const []);
  return ref.watch(itemRepositoryProvider).watchActiveItems(type: type);
});

/// Every item including deactivated ones. Used by admins only.
final allItemsProvider = StreamProvider<List<Item>>((ref) {
  if (ref.watch(signedInUidProvider) == null) return Stream.value(const []);
  return ref.watch(itemRepositoryProvider).watchAllItems();
});

/// One item by id; null if it does not exist.
final itemProvider = StreamProvider.family<Item?, String>((ref, id) {
  if (ref.watch(signedInUidProvider) == null) return Stream.value(null);
  return ref.watch(itemRepositoryProvider).watchItem(id);
});

/// The type chip currently selected on the home screen (null = "All").
class ItemTypeFilter extends Notifier<ItemType?> {
  @override
  ItemType? build() {
    // Depending on the user resets the filter to "All" for the next login.
    ref.watch(signedInUidProvider);
    return null;
  }

  void select(ItemType? type) => state = type;
}

final itemTypeFilterProvider = NotifierProvider<ItemTypeFilter, ItemType?>(
  ItemTypeFilter.new,
);

/// Admin actions on items, exposing loading / error state to the forms.
class ItemsController extends AsyncNotifier<void> with AsyncActionRunner {
  @override
  Future<void> build() async {}

  ItemRepository get _repository => ref.read(itemRepositoryProvider);

  Future<bool> create({
    required String title,
    required String description,
    required ItemType type,
    required bool isActive,
  }) {
    return runAction(() async {
      final uid = ref.read(authRepositoryProvider).currentUser?.uid;
      if (uid == null) throw const AppException('Please log in again.');
      await _repository.createItem(
        title: title,
        description: description,
        type: type,
        isActive: isActive,
        createdBy: uid,
      );
    });
  }

  Future<bool> saveChanges(Item item) =>
      runAction(() => _repository.updateItem(item));

  Future<bool> setActive(String id, {required bool isActive}) {
    return runAction(() => _repository.setActive(id, isActive: isActive));
  }
}

final itemsControllerProvider = AsyncNotifierProvider<ItemsController, void>(
  ItemsController.new,
);
