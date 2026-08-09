import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sportyapp/data/models/app_user.dart';

abstract class AuthService {
  AppUser? get currentUser;
  Future<AppUser> signUpSpectator({
    required String name,
    required String email,
    required String password,
    String? favoriteTournamentId,
  });
  Future<AppUser> signUpScorer({
    required String name,
    required String email,
    required String password,
    String? organization,
  });
  Future<AppUser> signUpWithGoogle({
    required AppUserRole role,
    String? organization,
  });
  Future<AppUser> signIn(String email, String password);
  Future<void> signOut();
  Stream<fa.User?> authStateChanges();
  Future<void> loadCurrentUser();
}

class FirebaseAuthService implements AuthService {
  final fa.FirebaseAuth _auth = fa.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  AppUser? _currentUser;

  @override
  AppUser? get currentUser => _currentUser;

  @override
  Stream<fa.User?> authStateChanges() => _auth.authStateChanges();

  @override
  Future<void> loadCurrentUser() async {
    final fbUser = _auth.currentUser;
    if (fbUser == null) {
      _currentUser = null;
      return;
    }
    final doc = await _firestore.collection('users').doc(fbUser.uid).get();
    if (doc.exists) {
      _currentUser = AppUser.fromJson(doc.data()!);
    } else {
      _currentUser = null;
    }
  }

  @override
  Future<AppUser> signUpSpectator({
    required String name,
    required String email,
    required String password,
    String? favoriteTournamentId,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = credential.user!.uid;

    final user = AppUser(
      id: uid,
      name: name,
      email: email,
      phone: '',
      address: '',
      role: AppUserRole.spectator,
      favoriteTournamentId: favoriteTournamentId,
      createdAt: DateTime.now(),
    );

    await _firestore.collection('users').doc(uid).set(user.toJson());
    _currentUser = user;
    return user;
  }

  @override
  Future<AppUser> signUpScorer({
    required String name,
    required String email,
    required String password,
    String? organization,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = credential.user!.uid;

    final user = AppUser(
      id: uid,
      name: name,
      email: email,
      phone: '',
      address: '',
      role: AppUserRole.scorer,
      organization: organization,
      createdAt: DateTime.now(),
    );

    await _firestore.collection('users').doc(uid).set(user.toJson());
    _currentUser = user;
    return user;
  }

  @override
  Future<AppUser> signUpWithGoogle({
    required AppUserRole role,
    String? organization,
  }) async {
    // Launch the Google account chooser. Returns null if the user cancels.
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      throw Exception('Google sign-in was cancelled');
    }
    final googleAuth = await googleUser.authentication;
    final credential = fa.GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    final userCredential = await _auth.signInWithCredential(credential);
    final uid = userCredential.user!.uid;

    final docRef = _firestore.collection('users').doc(uid);
    final doc = await docRef.get();
    final now = DateTime.now();
    if (doc.exists) {
      // Same Google account used again: adopt the freshly-chosen role so the
      // profile always matches where the user signed up from.
      final existing = AppUser.fromJson(doc.data()!);
      final updated = existing.copyWith(role: role, organization: organization);
      await docRef.set(updated.toJson());
      _currentUser = updated;
      return updated;
    }

    final user = AppUser(
      id: uid,
      name: googleUser.displayName ?? userCredential.user!.displayName ?? 'User',
      email: googleUser.email,
      phone: '',
      address: '',
      role: role,
      organization: organization,
      createdAt: now,
    );
    await docRef.set(user.toJson());
    _currentUser = user;
    return user;
  }

  @override
  Future<AppUser> signIn(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = credential.user!.uid;
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) {
      throw Exception('User profile not found');
    }
    _currentUser = AppUser.fromJson(doc.data()!);
    return _currentUser!;
  }

  @override
  Future<void> signOut() async {
    debugPrint('[DEBUG] FirebaseAuthService.signOut() CALLED. Stack: ${StackTrace.current}');
    await _auth.signOut();
    _currentUser = null;
  }
}
