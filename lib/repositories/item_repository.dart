import '../models/item.dart';
import '../services/firestore_service.dart';

/// Reads and writes `items/{itemId}`.
///
/// Queries use equality filters only and sort on the client, so they need no
/// composite index.
class ItemRepository {
  ItemRepository({required FirestoreService firestoreService})
    : _firestore = firestoreService;

  final FirestoreService _firestore;

  /// Active items for the user-facing browse list, optionally of one [type].
  Stream<List<Item>> watchActiveItems({ItemType? type}) {
    var query = _firestore.items.where('isActive', isEqualTo: true);
    if (type != null) query = query.where('type', isEqualTo: type.name);
    return query.snapshots().map(
      (snapshot) => _sortNewestFirst(
        snapshot.docs.map((doc) => _itemFrom(doc.id, doc.data())),
      ),
    );
  }

  /// Every item, including deactivated ones (admin management list).
  Stream<List<Item>> watchAllItems() {
    return _firestore.items.snapshots().map(
      (snapshot) => _sortNewestFirst(
        snapshot.docs.map((doc) => _itemFrom(doc.id, doc.data())),
      ),
    );
  }

  /// A single item; emits null if it does not exist.
  Stream<Item?> watchItem(String id) {
    return _firestore.items.doc(id).snapshots().map((snapshot) {
      final data = snapshot.data();
      return data == null ? null : _itemFrom(snapshot.id, data);
    });
  }

  /// Creates an item with zeroed rating aggregates. Returns the new id.
  Future<String> createItem({
    required String title,
    required String description,
    required ItemType type,
    required String createdBy,
    bool isActive = true,
  }) async {
    final doc = _firestore.items.doc();
    final item = Item(
      id: doc.id,
      title: title.trim(),
      description: description.trim(),
      type: type,
      isActive: isActive,
      createdBy: createdBy,
      createdAt: DateTime.now(),
    );
    await doc.set(item.toMap());
    return doc.id;
  }

  /// Updates the editable fields only. The rating aggregates are deliberately
  /// left alone so an admin edit can never overwrite them with stale values.
  Future<void> updateItem(Item item) {
    return _firestore.items.doc(item.id).update({
      'title': item.title.trim(),
      'description': item.description.trim(),
      'type': item.type.name,
      'isActive': item.isActive,
    });
  }

  Future<void> setActive(String id, {required bool isActive}) {
    return _firestore.items.doc(id).update({'isActive': isActive});
  }

  // The document id is authoritative even if the stored `id` field is missing.
  Item _itemFrom(String id, Map<String, dynamic> data) =>
      Item.fromMap({...data, 'id': id});

  List<Item> _sortNewestFirst(Iterable<Item> items) {
    return items.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
}
