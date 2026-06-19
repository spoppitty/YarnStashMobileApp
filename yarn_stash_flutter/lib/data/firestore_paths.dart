abstract final class FirestoreCollectionNames {
  static const users = 'users';
  static const stashCollections = 'stashCollections';
  static const yarns = 'yarns';
  static const folders = 'folders';
}

abstract final class FirestoreDocumentIds {
  static const defaultStashCollection = 'default';
  static const defaultUsedUpFolder = 'used-up';
}

abstract final class FirestorePaths {
  static String user(String uid) => '${FirestoreCollectionNames.users}/$uid';

  static String stashCollections(String uid) {
    return '${user(uid)}/${FirestoreCollectionNames.stashCollections}';
  }

  static String stashCollection(String uid, String collectionId) {
    return '${stashCollections(uid)}/$collectionId';
  }

  static String yarns(String uid, String collectionId) {
    return '${stashCollection(uid, collectionId)}/${FirestoreCollectionNames.yarns}';
  }

  static String yarn(String uid, String collectionId, String yarnId) {
    return '${yarns(uid, collectionId)}/$yarnId';
  }

  static String folders(String uid, String collectionId) {
    return '${stashCollection(uid, collectionId)}/${FirestoreCollectionNames.folders}';
  }

  static String folder(String uid, String collectionId, String folderId) {
    return '${folders(uid, collectionId)}/$folderId';
  }
}
