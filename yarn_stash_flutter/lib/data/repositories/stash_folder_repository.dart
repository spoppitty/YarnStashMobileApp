import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore_paths.dart';
import '../models/stash_folder.dart';

class StashFolderRepository {
  StashFolderRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<StashFolder> collectionRef({
    required String uid,
    required String collectionId,
  }) {
    return _firestore
        .collection(FirestorePaths.folders(uid, collectionId))
        .withConverter<StashFolder>(
          fromFirestore: (snapshot, _) => StashFolder.fromFirestore(snapshot),
          toFirestore: (folder, _) => folder.toFirestore(),
        );
  }

  DocumentReference<StashFolder> folderRef({
    required String uid,
    required String collectionId,
    required String folderId,
  }) {
    return collectionRef(uid: uid, collectionId: collectionId).doc(folderId);
  }

  Stream<List<StashFolder>> watchFolders({
    required String uid,
    String collectionId = FirestoreDocumentIds.defaultStashCollection,
  }) {
    return collectionRef(uid: uid, collectionId: collectionId).snapshots().map((
      snapshot,
    ) {
      final folders = snapshot.docs.map((doc) => doc.data()).toList();
      folders.sort((a, b) {
        if (a.isSystem != b.isSystem) {
          return a.isSystem ? -1 : 1;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      return folders.toList(growable: false);
    });
  }

  Stream<StashFolder?> watchFolder({
    required String uid,
    required String collectionId,
    required String folderId,
  }) {
    return folderRef(
      uid: uid,
      collectionId: collectionId,
      folderId: folderId,
    ).snapshots().map((snapshot) => snapshot.data());
  }

  Future<StashFolder> createFolder({
    required String uid,
    String collectionId = FirestoreDocumentIds.defaultStashCollection,
    required String name,
    required String iconKey,
    required int colorValue,
  }) async {
    final now = DateTime.now();
    final doc = collectionRef(uid: uid, collectionId: collectionId).doc();
    final folder = StashFolder(
      id: doc.id,
      ownerUid: uid,
      collectionId: collectionId,
      name: name,
      iconKey: iconKey,
      colorValue: colorValue,
      createdAt: now,
      updatedAt: now,
    );

    await doc.set(folder);
    return folder;
  }

  Future<void> ensureDefaultFolders(String uid) async {
    final now = DateTime.now();
    final collectionId = FirestoreDocumentIds.defaultStashCollection;
    final doc = folderRef(
      uid: uid,
      collectionId: collectionId,
      folderId: FirestoreDocumentIds.defaultUsedUpFolder,
    );
    final snapshot = await doc.get();

    if (snapshot.exists) {
      final folder = snapshot.data();
      if (folder != null && folder.isSystem) {
        return;
      }

      await doc.set(
        (folder ??
                StashFolder(
                  id: FirestoreDocumentIds.defaultUsedUpFolder,
                  ownerUid: uid,
                  collectionId: collectionId,
                  name: 'Used up',
                  createdAt: now,
                  updatedAt: now,
                ))
            .copyWith(isSystem: true, updatedAt: now),
        SetOptions(merge: true),
      );
      return;
    }

    await doc.set(
      StashFolder(
        id: FirestoreDocumentIds.defaultUsedUpFolder,
        ownerUid: uid,
        collectionId: collectionId,
        name: 'Used up',
        iconKey: 'circleCheck',
        colorValue: 0xFFEADFD5,
        isSystem: true,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> updateFolder(StashFolder folder) {
    return folderRef(
      uid: folder.ownerUid,
      collectionId: folder.collectionId,
      folderId: folder.id,
    ).set(folder.copyWith(updatedAt: DateTime.now()), SetOptions(merge: true));
  }

  Future<void> deleteFolder({
    required String uid,
    required String collectionId,
    required String folderId,
  }) async {
    final doc = folderRef(
      uid: uid,
      collectionId: collectionId,
      folderId: folderId,
    );
    final snapshot = await doc.get();
    final folder = snapshot.data();

    if (folder == null || folder.isSystem) {
      return;
    }

    final batch = _firestore.batch();
    for (final yarnId in folder.yarnIds) {
      batch.update(
        _firestore.doc(FirestorePaths.yarn(uid, collectionId, yarnId)),
        {
          'folderIds': FieldValue.arrayRemove([folderId]),
          'folderName': null,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        },
      );
    }
    batch.delete(doc);
    await batch.commit();
  }

  Future<void> syncYarnMembership({
    required String uid,
    required String collectionId,
    required String yarnId,
    required List<String> previousFolderIds,
    required List<String> nextFolderIds,
  }) async {
    final previous = previousFolderIds.toSet();
    final next = nextFolderIds.toSet();
    final removed = previous.difference(next);
    final added = next.difference(previous);

    if (removed.isEmpty && added.isEmpty) {
      return;
    }

    final batch = _firestore.batch();

    for (final folderId in removed) {
      batch.update(
        _firestore.doc(FirestorePaths.folder(uid, collectionId, folderId)),
        {
          'yarnIds': FieldValue.arrayRemove([yarnId]),
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        },
      );
    }

    for (final folderId in added) {
      batch.update(
        _firestore.doc(FirestorePaths.folder(uid, collectionId, folderId)),
        {
          'yarnIds': FieldValue.arrayUnion([yarnId]),
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        },
      );
    }

    await batch.commit();
  }
}
