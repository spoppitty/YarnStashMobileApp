import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore_paths.dart';
import '../firestore_serializers.dart';

class StashFolder {
  const StashFolder({
    required this.id,
    required this.ownerUid,
    required this.collectionId,
    required this.name,
    this.iconKey = 'folder',
    this.colorValue = 0xFFF6D9CD,
    this.yarnIds = const [],
    this.isSystem = false,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String ownerUid;
  final String collectionId;
  final String name;
  final String iconKey;
  final int colorValue;
  final List<String> yarnIds;
  final bool isSystem;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isDefaultUsedUp {
    return id == FirestoreDocumentIds.defaultUsedUpFolder;
  }

  factory StashFolder.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final now = DateTime.now();

    return StashFolder(
      id: doc.id,
      ownerUid: data['ownerUid'] as String? ?? '',
      collectionId: data['collectionId'] as String? ?? '',
      name: data['name'] as String? ?? '',
      iconKey: data['iconKey'] as String? ?? 'folder',
      colorValue: intFromFirestore(data['colorValue'], fallback: 0xFFF6D9CD),
      yarnIds: stringListFromFirestore(data['yarnIds']),
      isSystem: data['isSystem'] as bool? ?? false,
      createdAt: dateTimeFromFirestore(data['createdAt']) ?? now,
      updatedAt: dateTimeFromFirestore(data['updatedAt']) ?? now,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'ownerUid': ownerUid,
      'collectionId': collectionId,
      'name': name,
      'iconKey': iconKey,
      'colorValue': colorValue,
      'yarnIds': yarnIds,
      'isSystem': isSystem,
      'createdAt': dateTimeToFirestore(createdAt),
      'updatedAt': dateTimeToFirestore(updatedAt),
    };
  }

  StashFolder copyWith({
    String? id,
    String? ownerUid,
    String? collectionId,
    String? name,
    String? iconKey,
    int? colorValue,
    List<String>? yarnIds,
    bool? isSystem,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StashFolder(
      id: id ?? this.id,
      ownerUid: ownerUid ?? this.ownerUid,
      collectionId: collectionId ?? this.collectionId,
      name: name ?? this.name,
      iconKey: iconKey ?? this.iconKey,
      colorValue: colorValue ?? this.colorValue,
      yarnIds: yarnIds ?? this.yarnIds,
      isSystem: isSystem ?? this.isSystem,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
