import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore_paths.dart';
import '../models/app_user.dart';

class UserRepository {
  UserRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _userMapRef(String uid) {
    return _firestore.doc(FirestorePaths.user(uid));
  }

  DocumentReference<AppUser> userRef(String uid) {
    return _userMapRef(uid).withConverter<AppUser>(
      fromFirestore: (snapshot, _) => AppUser.fromFirestore(snapshot),
      toFirestore: (user, _) => user.toFirestore(),
    );
  }

  Stream<AppUser?> watchUser(String uid) {
    return userRef(uid).snapshots().map((snapshot) => snapshot.data());
  }

  Future<AppUser?> getUser(String uid) async {
    final snapshot = await userRef(uid).get();
    return snapshot.data();
  }

  Future<void> upsertUser(AppUser user) async {
    await userRef(user.uid).set(user, SetOptions(merge: true));
    await _userMapRef(user.uid).update({
      'defaultLengthUnit': FieldValue.delete(),
      'defaultWeightUnit': FieldValue.delete(),
    });
  }
}
