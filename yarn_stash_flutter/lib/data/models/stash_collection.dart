import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore_serializers.dart';

class StashCollection {
  const StashCollection({
    required this.id,
    required this.ownerUid,
    required this.name,
    this.description,
    this.yarnCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String ownerUid;
  final String name;
  final String? description;
  final int yarnCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory StashCollection.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final now = DateTime.now();

    return StashCollection(
      id: doc.id,
      ownerUid: data['ownerUid'] as String? ?? '',
      name: data['name'] as String? ?? '',
      description: data['description'] as String?,
      yarnCount: intFromFirestore(data['yarnCount']),
      createdAt: dateTimeFromFirestore(data['createdAt']) ?? now,
      updatedAt: dateTimeFromFirestore(data['updatedAt']) ?? now,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'ownerUid': ownerUid,
      'name': name,
      'description': description,
      'yarnCount': yarnCount,
      'createdAt': dateTimeToFirestore(createdAt),
      'updatedAt': dateTimeToFirestore(updatedAt),
    };
  }

  StashCollection copyWith({
    String? id,
    String? ownerUid,
    String? name,
    String? description,
    int? yarnCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StashCollection(
      id: id ?? this.id,
      ownerUid: ownerUid ?? this.ownerUid,
      name: name ?? this.name,
      description: description ?? this.description,
      yarnCount: yarnCount ?? this.yarnCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
