import 'package:flutter_test/flutter_test.dart';
import 'package:yarn_stash/data/yarn_stash_data.dart';

void main() {
  group('FirestorePaths', () {
    test('builds the user-scoped stash hierarchy', () {
      expect(FirestorePaths.user('uid-1'), 'users/uid-1');
      expect(
        FirestorePaths.stashCollections('uid-1'),
        'users/uid-1/stashCollections',
      );
      expect(
        FirestorePaths.stashCollection('uid-1', 'default'),
        'users/uid-1/stashCollections/default',
      );
      expect(
        FirestorePaths.yarns('uid-1', 'default'),
        'users/uid-1/stashCollections/default/yarns',
      );
      expect(
        FirestorePaths.yarn('uid-1', 'default', 'yarn-1'),
        'users/uid-1/stashCollections/default/yarns/yarn-1',
      );
    });
  });

  group('Firestore models', () {
    test('serializes user preferences with stable enum values', () {
      final user = AppUser(
        uid: 'uid-1',
        email: 'sarah@example.com',
        displayName: 'Sarah',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );

      final data = user.toFirestore();

      expect(data['uid'], 'uid-1');
      expect(data['defaultLengthUnit'], 'yards');
      expect(data['defaultWeightUnit'], 'grams');
    });

    test('serializes yarn ownership and status fields', () {
      final yarn = Yarn(
        id: 'yarn-1',
        ownerUid: 'uid-1',
        collectionId: FirestoreDocumentIds.defaultStashCollection,
        brandName: 'Malabrigo',
        name: 'Rios',
        wpi: 9,
        fiberContents: const [
          YarnFiberContent(fiber: 'Merino', percentage: 100),
        ],
        folderName: 'Sweaters',
        status: YarnStatus.inStash,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );

      final data = yarn.toFirestore();

      expect(data['ownerUid'], 'uid-1');
      expect(data['collectionId'], 'default');
      expect(data['status'], 'inStash');
      expect(data['skeinCount'], 1);
      expect(data['wpi'], 9);
      expect(data['fiberContent'], '100% Merino');
      expect(data['fiberContents'], [
        {'fiber': 'Merino', 'percentage': 100},
      ]);
      expect(data['folderName'], 'Sweaters');
    });
  });
}
