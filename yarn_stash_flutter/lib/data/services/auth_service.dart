import 'package:firebase_auth/firebase_auth.dart';

import '../firestore_paths.dart';
import '../models/app_user.dart';
import '../repositories/stash_collection_repository.dart';
import '../repositories/stash_folder_repository.dart';
import '../repositories/user_repository.dart';
import 'package:google_sign_in/google_sign_in.dart';

class UserProfileUpdateResult {
  const UserProfileUpdateResult({required this.emailVerificationSent});

  final bool emailVerificationSent;
}

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

  Future<UserCredential> signInWithGoogle() async {
    await GoogleSignIn.instance.initialize(
      serverClientId: "939927765385-416j2ncs5fqnvt0c7kqnggsfjpq3vjrp.apps.googleusercontent.com",
    );

    final googleUser = await GoogleSignIn.instance.authenticate();
    final googleAuth = googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );

    return FirebaseAuth.instance.signInWithCredential(credential);
  }

  Future<void> sendPasswordResetEmail(String email) {
    return _firebaseAuth.sendPasswordResetEmail(email: email.trim());
  }

  Future<UserProfileUpdateResult> updateSignedInUserProfile({
    required String displayName,
    required String email,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw StateError('Cannot update a profile without a signed-in user.');
    }

    final trimmedDisplayName = displayName.trim();
    final trimmedEmail = email.trim();
    if (trimmedDisplayName.isEmpty) {
      throw ArgumentError.value(displayName, 'displayName', 'Required');
    }

    final now = DateTime.now();
    final existingUser = await _userRepository.getUser(user.uid);
    final currentAuthEmail = user.email?.trim();
    final existingEmail = existingUser?.email?.trim();
    var persistedEmail = currentAuthEmail?.isNotEmpty == true
        ? currentAuthEmail
        : existingEmail;
    var emailVerificationSent = false;

    if ((user.displayName ?? '').trim() != trimmedDisplayName) {
      await user.updateDisplayName(trimmedDisplayName);
    }

    if (trimmedEmail.isNotEmpty && trimmedEmail != currentAuthEmail) {
      await user.verifyBeforeUpdateEmail(trimmedEmail);
      emailVerificationSent = true;
    } else if (trimmedEmail.isNotEmpty) {
      persistedEmail = trimmedEmail;
    }

    await _userRepository.upsertUser(
      (existingUser ??
              AppUser(
                uid: user.uid,
                email: persistedEmail,
                displayName: trimmedDisplayName,
                createdAt: now,
                updatedAt: now,
              ))
          .copyWith(
            email: persistedEmail,
            displayName: trimmedDisplayName,
            updatedAt: now,
          ),
    );

    return UserProfileUpdateResult(
      emailVerificationSent: emailVerificationSent,
    );
  }

  Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();
    await FirebaseAuth.instance.signOut();
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
