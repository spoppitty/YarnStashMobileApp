import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore_paths.dart';
import '../models/stash_collection.dart';

class StashCollectionRepository {
  StashCollectionRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<StashCollection> collectionRef(String uid) {
    return _firestore
        .collection(FirestorePaths.stashCollections(uid))
        .withConverter<StashCollection>(
          fromFirestore: (snapshot, _) =>
              StashCollection.fromFirestore(snapshot),
          toFirestore: (collection, _) => collection.toFirestore(),
        );
  }

  DocumentReference<StashCollection> stashCollectionRef(
    String uid,
    String collectionId,
  ) {
    return collectionRef(uid).doc(collectionId);
  }

  Stream<List<StashCollection>> watchCollections(String uid) {
    return collectionRef(
      uid,
    ).orderBy('updatedAt', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => doc.data()).toList(growable: false);
    });
  }

  Future<StashCollection> createCollection({
    required String uid,
    required String name,
    String? description,
  }) async {
    final now = DateTime.now();
    final doc = collectionRef(uid).doc();
    final collection = StashCollection(
      id: doc.id,
      ownerUid: uid,
      name: name,
      description: description,
      createdAt: now,
      updatedAt: now,
    );

    await doc.set(collection);
    return collection;
  }

  Future<void> ensureDefaultCollection(String uid) async {
    final now = DateTime.now();
    final doc = stashCollectionRef(
      uid,
      FirestoreDocumentIds.defaultStashCollection,
    );
    final snapshot = await doc.get();

    if (snapshot.exists) {
      return;
    }

    await doc.set(
      StashCollection(
        id: FirestoreDocumentIds.defaultStashCollection,
        ownerUid: uid,
        name: 'My Stash',
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> updateCollection(StashCollection collection) {
    return stashCollectionRef(collection.ownerUid, collection.id).set(
      collection.copyWith(updatedAt: DateTime.now()),
      SetOptions(merge: true),
    );
  }

  Future<void> deleteCollection({
    required String uid,
    required String collectionId,
  }) {
    return stashCollectionRef(uid, collectionId).delete();
  }
}
