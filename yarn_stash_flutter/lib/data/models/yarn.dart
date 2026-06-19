import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore_serializers.dart';

enum YarnStatus {
  inStash('inStash'),
  inProject('inProject'),
  usedUp('usedUp'),
  destashed('destashed');

  const YarnStatus(this.firestoreValue);

  final String firestoreValue;

  static YarnStatus fromFirestore(Object? value) {
    return YarnStatus.values.firstWhere(
      (status) => status.firestoreValue == value,
      orElse: () => YarnStatus.inStash,
    );
  }
}

class Yarn {
  const Yarn({
    required this.id,
    required this.ownerUid,
    required this.collectionId,
    required this.brandName,
    required this.name,
    this.colorway,
    this.colorFamily,
    this.dyeLot,
    this.weightCategory,
    this.wpi,
    this.fiberContent,
    this.yardage,
    this.unitWeightGrams,
    this.needleSize,
    this.gauge,
    this.skeinCount = 1,
    this.priceCents,
    this.status = YarnStatus.inStash,
    this.imageUrls = const [],
    this.folderName,
    this.folderIds = const [],
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String ownerUid;
  final String collectionId;
  final String brandName;
  final String name;
  final String? colorway;
  final String? colorFamily;
  final String? dyeLot;
  final String? weightCategory;
  final int? wpi;
  final String? fiberContent;
  final int? yardage;
  final int? unitWeightGrams;
  final String? needleSize;
  final String? gauge;
  final int skeinCount;
  final int? priceCents;
  final YarnStatus status;
  final List<String> imageUrls;
  final String? folderName;
  final List<String> folderIds;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Yarn.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final now = DateTime.now();

    return Yarn(
      id: doc.id,
      ownerUid: data['ownerUid'] as String? ?? '',
      collectionId: data['collectionId'] as String? ?? '',
      brandName: data['brandName'] as String? ?? '',
      name: data['name'] as String? ?? '',
      colorway: data['colorway'] as String?,
      colorFamily: data['colorFamily'] as String?,
      dyeLot: data['dyeLot'] as String?,
      weightCategory: data['weightCategory'] as String?,
      wpi: data['wpi'] == null ? null : intFromFirestore(data['wpi']),
      fiberContent: data['fiberContent'] as String?,
      yardage: data['yardage'] == null
          ? null
          : intFromFirestore(data['yardage']),
      unitWeightGrams: data['unitWeightGrams'] == null
          ? null
          : intFromFirestore(data['unitWeightGrams']),
      needleSize: data['needleSize'] as String?,
      gauge: data['gauge'] as String?,
      skeinCount: intFromFirestore(data['skeinCount'], fallback: 1),
      priceCents: data['priceCents'] == null
          ? null
          : intFromFirestore(data['priceCents']),
      status: YarnStatus.fromFirestore(data['status']),
      imageUrls: stringListFromFirestore(data['imageUrls']),
      folderName: data['folderName'] as String?,
      folderIds: stringListFromFirestore(data['folderIds']),
      notes: data['notes'] as String?,
      createdAt: dateTimeFromFirestore(data['createdAt']) ?? now,
      updatedAt: dateTimeFromFirestore(data['updatedAt']) ?? now,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'ownerUid': ownerUid,
      'collectionId': collectionId,
      'brandName': brandName,
      'name': name,
      'colorway': colorway,
      'colorFamily': colorFamily,
      'dyeLot': dyeLot,
      'weightCategory': weightCategory,
      'wpi': wpi,
      'fiberContent': fiberContent,
      'yardage': yardage,
      'unitWeightGrams': unitWeightGrams,
      'needleSize': needleSize,
      'gauge': gauge,
      'skeinCount': skeinCount,
      'priceCents': priceCents,
      'status': status.firestoreValue,
      'imageUrls': imageUrls,
      'folderName': folderName,
      'folderIds': folderIds,
      'notes': notes,
      'createdAt': dateTimeToFirestore(createdAt),
      'updatedAt': dateTimeToFirestore(updatedAt),
    };
  }

  Yarn copyWith({
    String? id,
    String? ownerUid,
    String? collectionId,
    String? brandName,
    String? name,
    String? colorway,
    String? colorFamily,
    String? dyeLot,
    String? weightCategory,
    int? wpi,
    String? fiberContent,
    int? yardage,
    int? unitWeightGrams,
    String? needleSize,
    String? gauge,
    int? skeinCount,
    int? priceCents,
    YarnStatus? status,
    List<String>? imageUrls,
    String? folderName,
    List<String>? folderIds,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Yarn(
      id: id ?? this.id,
      ownerUid: ownerUid ?? this.ownerUid,
      collectionId: collectionId ?? this.collectionId,
      brandName: brandName ?? this.brandName,
      name: name ?? this.name,
      colorway: colorway ?? this.colorway,
      colorFamily: colorFamily ?? this.colorFamily,
      dyeLot: dyeLot ?? this.dyeLot,
      weightCategory: weightCategory ?? this.weightCategory,
      wpi: wpi ?? this.wpi,
      fiberContent: fiberContent ?? this.fiberContent,
      yardage: yardage ?? this.yardage,
      unitWeightGrams: unitWeightGrams ?? this.unitWeightGrams,
      needleSize: needleSize ?? this.needleSize,
      gauge: gauge ?? this.gauge,
      skeinCount: skeinCount ?? this.skeinCount,
      priceCents: priceCents ?? this.priceCents,
      status: status ?? this.status,
      imageUrls: imageUrls ?? this.imageUrls,
      folderName: folderName ?? this.folderName,
      folderIds: folderIds ?? this.folderIds,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
