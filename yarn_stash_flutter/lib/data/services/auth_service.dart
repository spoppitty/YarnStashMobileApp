import 'package:firebase_auth/firebase_auth.dart';

import '../firestore_paths.dart';
import '../models/app_user.dart';
import '../repositories/stash_collection_repository.dart';
import '../repositories/stash_folder_repository.dart';
import '../repositories/user_repository.dart';

class AuthService {
  AuthService({
    FirebaseAuth? firebaseAuth,
    UserRepository? userRepository,
    StashCollectionRepository? stashCollectionRepository,
    StashFolderRepository? stashFolderRepository,
  }) : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
       _userRepository = userRepository ?? UserRepository(),
       _stashCollectionRepository =
           stashCollectionRepository ?? StashCollectionRepository(),
       _stashFolderRepository =
           stashFolderRepository ?? StashFolderRepository();

  final FirebaseAuth _firebaseAuth;
  final UserRepository _userRepository;
  final StashCollectionRepository _stashCollectionRepository;
  final StashFolderRepository _stashFolderRepository;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  User? get currentUser => _firebaseAuth.currentUser;

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    return _firebaseAuth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = credential.user;

    if (user == null) {
      return credential;
    }

    final trimmedDisplayName = displayName.trim();
    if (trimmedDisplayName.isNotEmpty) {
      await user.updateDisplayName(trimmedDisplayName);
    }

    await _bootstrapUserProfile(
      uid: user.uid,
      email: user.email ?? email.trim(),
      displayName: trimmedDisplayName,
    );

    return credential;
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _firebaseAuth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() {
    return _firebaseAuth.signOut();
  }

  Future<void> ensureSignedInUserProfile() async {
    final user = currentUser;
    if (user == null) {
      return;
    }

    await _bootstrapUserProfile(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName ?? '',
    );
  }

  Future<void> _bootstrapUserProfile({
    required String uid,
    required String? email,
    required String displayName,
  }) async {
    final now = DateTime.now();
    final existingUser = await _userRepository.getUser(uid);
    final existingDisplayName = existingUser?.displayName.trim();
    final resolvedDisplayName =
        existingDisplayName != null && existingDisplayName.isNotEmpty
        ? existingUser!.displayName
        : displayName.trim();

    await _userRepository.upsertUser(
      AppUser(
        uid: uid,
        email: email,
        displayName: resolvedDisplayName,
        defaultLengthUnit: existingUser?.defaultLengthUnit ?? LengthUnit.yards,
        defaultWeightUnit: existingUser?.defaultWeightUnit ?? WeightUnit.grams,
        createdAt: existingUser?.createdAt ?? now,
        updatedAt: now,
      ),
    );

    await _stashCollectionRepository.ensureDefaultCollection(uid);
    await _stashFolderRepository.ensureDefaultFolders(uid);
  }

  String get defaultStashCollectionId {
    return FirestoreDocumentIds.defaultStashCollection;
  }
}
