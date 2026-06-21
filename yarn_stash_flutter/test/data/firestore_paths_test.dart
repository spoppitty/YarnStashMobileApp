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
      expect(
        FirestorePaths.folders('uid-1', 'default'),
        'users/uid-1/stashCollections/default/folders',
      );
      expect(
        FirestorePaths.folder('uid-1', 'default', 'used-up'),
        'users/uid-1/stashCollections/default/folders/used-up',
      );
    });
  });

  group('Firestore models', () {
    test('serializes user profile fields without stash preferences', () {
      final user = AppUser(
        uid: 'uid-1',
        email: 'sarah@example.com',
        displayName: 'Sarah',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );

      final data = user.toFirestore();

      expect(data['uid'], 'uid-1');
      expect(data['email'], 'sarah@example.com');
      expect(data['displayName'], 'Sarah');
      expect(data.containsKey('defaultLengthUnit'), isFalse);
      expect(data.containsKey('defaultWeightUnit'), isFalse);
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

    test('serializes stash folder display and yarn membership fields', () {
      final folder = StashFolder(
        id: FirestoreDocumentIds.defaultUsedUpFolder,
        ownerUid: 'uid-1',
        collectionId: FirestoreDocumentIds.defaultStashCollection,
        name: 'Used up',
        iconKey: 'circleCheck',
        colorValue: 0xFFEADFD5,
        yarnIds: const ['yarn-1'],
        isSystem: true,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );

      final data = folder.toFirestore();

      expect(data['ownerUid'], 'uid-1');
      expect(data['collectionId'], 'default');
      expect(data['name'], 'Used up');
      expect(data['iconKey'], 'circleCheck');
      expect(data['colorValue'], 0xFFEADFD5);
      expect(data['yarnIds'], ['yarn-1']);
      expect(data['isSystem'], isTrue);
    });

    test('normalizes Ravelry yarn catalog payloads', () {
      final yarn = RavelryYarnCatalogItem.fromJson({
        'id': 123,
        'name': 'Rios',
        'permalink': 'malabrigo-yarn-rios',
        'yarn_company_name': 'Malabrigo Yarn',
        'yarn_weight_name': 'Worsted',
        'fiber_content': '100% Merino',
        'yardage': 210,
        'grams': 100,
        'first_photo': {'small_url': 'https://example.com/rios.jpg'},
      });

      expect(yarn.id, 123);
      expect(yarn.name, 'Rios');
      expect(yarn.brandName, 'Malabrigo Yarn');
      expect(yarn.weightName, 'Worsted');
      expect(yarn.fiberContents.single.fiber, 'Merino');
      expect(yarn.fiberContents.single.percentage, 100);
      expect(yarn.yardage, 210);
      expect(yarn.unitWeightGrams, 100);
      expect(yarn.imageUrl, 'https://example.com/rios.jpg');
      expect(yarn.chips, ['Worsted', '100% Merino']);
    });
  });
}
