import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_paths.dart';

typedef JsonMap = Map<String, dynamic>;

/// Thin wrapper over [FirebaseFirestore] exposing the app's collection
/// references. Query logic belongs in the repositories, not here.
class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<JsonMap> get users => _db.collection(FirestorePaths.users);

  CollectionReference<JsonMap> get items => _db.collection(FirestorePaths.items);

  CollectionReference<JsonMap> get feedback =>
      _db.collection(FirestorePaths.feedback);

  /// Runs [handler] atomically; used to keep an item's rating aggregates in
  /// step with feedback writes.
  Future<T> runTransaction<T>(TransactionHandler<T> handler) =>
      _db.runTransaction(handler);
}
