import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yarn_stash/data/services/auth_service.dart';
import 'package:yarn_stash/screens.dart';

class _FakeAuthService implements AuthService {
  @override
  Stream<User?> get authStateChanges => Stream<User?>.value(null);

  @override
  User? get currentUser => null;

  @override
  String get defaultStashCollectionId => 'default';

  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> ensureSignedInUserProfile() {
    throw UnimplementedError();
  }

  @override
  Future<void> sendPasswordResetEmail(String email) {
    throw UnimplementedError();
  }

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> signOut() {
    throw UnimplementedError();
  }

  @override
  Future<UserProfileUpdateResult> updateSignedInUserProfile({
    required String displayName,
    required String email,
  }) {
    throw UnimplementedError();
  }
}

void main() {
  testWidgets('renders the Yarn Stash login screen', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoginScreen(
            authService: _FakeAuthService(),
            onLogin: () {},
            onSignUp: () {},
            onForgotPassword: () {},
          ),
        ),
      ),
    );

    expect(find.text('Yarn Stash'), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
  });
}
