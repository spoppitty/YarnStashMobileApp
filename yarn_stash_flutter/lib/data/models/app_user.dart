import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore_serializers.dart';

enum LengthUnit {
  yards('yards'),
  meters('meters');

  const LengthUnit(this.firestoreValue);

  final String firestoreValue;

  static LengthUnit fromFirestore(Object? value) {
    return LengthUnit.values.firstWhere(
      (unit) => unit.firestoreValue == value,
      orElse: () => LengthUnit.yards,
    );
  }
}

enum WeightUnit {
  grams('grams'),
  ounces('ounces');

  const WeightUnit(this.firestoreValue);

  final String firestoreValue;

  static WeightUnit fromFirestore(Object? value) {
    return WeightUnit.values.firstWhere(
      (unit) => unit.firestoreValue == value,
      orElse: () => WeightUnit.grams,
    );
  }
}

class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.defaultLengthUnit = LengthUnit.yards,
    this.defaultWeightUnit = WeightUnit.grams,
    required this.createdAt,
    required this.updatedAt,
  });

  final String uid;
  final String? email;
  final String displayName;
  final LengthUnit defaultLengthUnit;
  final WeightUnit defaultWeightUnit;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory AppUser.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final now = DateTime.now();

    return AppUser(
      uid: data['uid'] as String? ?? doc.id,
      email: data['email'] as String?,
      displayName: data['displayName'] as String? ?? '',
      defaultLengthUnit: LengthUnit.fromFirestore(data['defaultLengthUnit']),
      defaultWeightUnit: WeightUnit.fromFirestore(data['defaultWeightUnit']),
      createdAt: dateTimeFromFirestore(data['createdAt']) ?? now,
      updatedAt: dateTimeFromFirestore(data['updatedAt']) ?? now,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'defaultLengthUnit': defaultLengthUnit.firestoreValue,
      'defaultWeightUnit': defaultWeightUnit.firestoreValue,
      'createdAt': dateTimeToFirestore(createdAt),
      'updatedAt': dateTimeToFirestore(updatedAt),
    };
  }

  AppUser copyWith({
    String? uid,
    String? email,
    String? displayName,
    LengthUnit? defaultLengthUnit,
    WeightUnit? defaultWeightUnit,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      defaultLengthUnit: defaultLengthUnit ?? this.defaultLengthUnit,
      defaultWeightUnit: defaultWeightUnit ?? this.defaultWeightUnit,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
