import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore_serializers.dart';

class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.createdAt,
    required this.updatedAt,
  });

  final String uid;
  final String? email;
  final String displayName;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory AppUser.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final now = DateTime.now();

    return AppUser(
      uid: data['uid'] as String? ?? doc.id,
      email: data['email'] as String?,
      displayName: data['displayName'] as String? ?? '',
      createdAt: dateTimeFromFirestore(data['createdAt']) ?? now,
      updatedAt: dateTimeFromFirestore(data['updatedAt']) ?? now,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'createdAt': dateTimeToFirestore(createdAt),
      'updatedAt': dateTimeToFirestore(updatedAt),
    };
  }

  AppUser copyWith({
    String? uid,
    String? email,
    String? displayName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppUser(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
