import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore_paths.dart';
import '../models/yarn.dart';

class YarnRepository {
  YarnRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Yarn> collectionRef({
    required String uid,
    required String collectionId,
  }) {
    return _firestore
        .collection(FirestorePaths.yarns(uid, collectionId))
        .withConverter<Yarn>(
          fromFirestore: (snapshot, _) => Yarn.fromFirestore(snapshot),
          toFirestore: (yarn, _) => yarn.toFirestore(),
        );
  }

  DocumentReference<Yarn> yarnRef({
    required String uid,
    required String collectionId,
    required String yarnId,
  }) {
    return collectionRef(uid: uid, collectionId: collectionId).doc(yarnId);
  }

  Stream<List<Yarn>> watchYarns({
    required String uid,
    String collectionId = FirestoreDocumentIds.defaultStashCollection,
  }) {
    return collectionRef(
      uid: uid,
      collectionId: collectionId,
    ).orderBy('createdAt', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => doc.data()).toList(growable: false);
    });
  }

  Future<Yarn> createYarn({
    required String uid,
    String collectionId = FirestoreDocumentIds.defaultStashCollection,
    required Yarn yarn,
  }) async {
    final now = DateTime.now();
    final doc = collectionRef(uid: uid, collectionId: collectionId).doc();
    final createdYarn = yarn.copyWith(
      id: doc.id,
      ownerUid: uid,
      collectionId: collectionId,
      createdAt: now,
      updatedAt: now,
    );

    await doc.set(createdYarn);
    return createdYarn;
  }

  Future<void> updateYarn(Yarn yarn) {
    return yarnRef(
      uid: yarn.ownerUid,
      collectionId: yarn.collectionId,
      yarnId: yarn.id,
    ).set(yarn.copyWith(updatedAt: DateTime.now()), SetOptions(merge: true));
  }

  Future<void> deleteYarn({
    required String uid,
    required String collectionId,
    required String yarnId,
  }) {
    return yarnRef(
      uid: uid,
      collectionId: collectionId,
      yarnId: yarnId,
    ).delete();
  }
}
