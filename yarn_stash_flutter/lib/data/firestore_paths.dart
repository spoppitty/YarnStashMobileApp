abstract final class FirestoreCollectionNames {
  static const users = 'users';
  static const stashCollections = 'stashCollections';
  static const yarns = 'yarns';
}

abstract final class FirestoreDocumentIds {
  static const defaultStashCollection = 'default';
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
}
