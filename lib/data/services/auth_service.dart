import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sportyapp/data/models/app_user.dart';

class AccountDeletedException implements Exception {
  final String message;
  final String email;
  final String password;
  AccountDeletedException(this.message, this.email, this.password);
  @override
  String toString() => message;
}

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
  Future<AppUser?> signUpWithGoogle({
    required AppUserRole role,
    String? organization,
  });
  Future<AppUser> signIn(String email, String password);
  Future<AppUser> reactivateAccount(String email, String password);
  Future<void> switchToRole(AppUserRole targetRole) async {}
  Future<void> softDeleteAccount(String email, String password) async {}
  Future<void> signOut();
  Stream<fa.User?> authStateChanges();
  Future<void> loadCurrentUser();
}

class FirebaseAuthService implements AuthService {
  final fa.FirebaseAuth _auth = fa.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  @override
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
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final fbUser = credential.user;

      if (fbUser != null) {
        try {
          await fbUser.sendEmailVerification();
        } catch (e) {
          debugPrint('Error sending email verification: $e');
        }
      }

      final uid = fbUser!.uid;
      await Future.delayed(const Duration(milliseconds: 600));

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

      for (int attempt = 0; attempt < 3; attempt++) {
        try {
          await _firestore.collection('users').doc(uid).set(user.toJson(), SetOptions(merge: true));
          await _firestore.collection('spectators').doc(uid).set(user.toJson(), SetOptions(merge: true));
          break;
        } catch (e) {
          if (attempt == 2) {
            debugPrint('Error saving user to Firestore: $e');
            rethrow;
          }
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      _currentUser = user;
      return user;
    } on fa.FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException during spectator sign up: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error during spectator sign up: $e');
      rethrow;
    }
  }

  @override
  Future<AppUser> signUpScorer({
    required String name,
    required String email,
    required String password,
    String? organization,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final fbUser = credential.user;

      if (fbUser != null) {
        try {
          await fbUser.sendEmailVerification();
        } catch (e) {
          debugPrint('Error sending email verification: $e');
        }
      }

      final uid = fbUser!.uid;
      await Future.delayed(const Duration(milliseconds: 600));

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

      for (int attempt = 0; attempt < 3; attempt++) {
        try {
          await _firestore.collection('users').doc(uid).set(user.toJson(), SetOptions(merge: true));
          await _firestore.collection('scorers').doc(uid).set(user.toJson(), SetOptions(merge: true));
          break;
        } catch (e) {
          if (attempt == 2) {
            debugPrint('Error saving user to Firestore: $e');
            rethrow;
          }
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      _currentUser = user;
      return user;
    } on fa.FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException during scorer sign up: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Unexpected error during scorer sign up: $e');
      rethrow;
    }
  }

  @override
  Future<AppUser?> signUpWithGoogle({
    required AppUserRole role,
    String? organization,
  }) async {
    try {
      // Always sign out first so the account chooser is shown every time,
      // preventing the SDK from silently reusing the last-used account.
      try {
        await _googleSignIn.signOut();
      } catch (e) {
        debugPrint('Google Sign-In signout cleanup warning: $e');
      }

      // Launch Google account chooser. Returns null if user cancels.
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // User cancelled sign in
        return null;
      }

      final googleAuth = await googleUser.authentication;
      if (googleAuth.idToken == null && googleAuth.accessToken == null) {
        throw Exception('Google authentication tokens could not be retrieved. Please try again.');
      }

      final credential = fa.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      final fbUser = userCredential.user!;
      final uid = fbUser.uid;

      // Use the userCredential.user reference directly (guaranteed non-null).
      // reload() flushes any stale local state, then getIdToken(true) fetches
      // a fresh token from Firebase servers — Firestore uses this cached token
      // for all subsequent requests, eliminating the permission-denied race.
      try {
        await fbUser.reload();
        await fbUser.getIdToken(true);
      } catch (e) {
        debugPrint('Token refresh warning (non-fatal): $e');
      }

      final docRef = _firestore.collection('users').doc(uid);
      DocumentSnapshot<Map<String, dynamic>>? doc;

      // Read with retry — on permission-denied, refresh token then retry.
      for (int attempt = 0; attempt < 4; attempt++) {
        try {
          doc = await docRef.get();
          break;
        } catch (e) {
          if (attempt == 3) {
            debugPrint('Error getting user doc from Firestore: $e');
            rethrow;
          }
          final isPermission = e is FirebaseException && e.code == 'permission-denied';
          if (isPermission) {
            debugPrint('Firestore read permission-denied (attempt $attempt), refreshing token...');
            try { await fbUser.getIdToken(true); } catch (_) {}
          }
          await Future.delayed(Duration(milliseconds: isPermission ? 800 : 500));
        }
      }

      final now = DateTime.now();
      if (doc != null && doc.exists && doc.data() != null) {
        try {
          final existing = AppUser.fromJson(doc.data()!);
          _currentUser = existing;
          return existing;
        } catch (_) {
          // If parsing fails, recreate user profile
        }
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

      // Write with retry — on permission-denied, refresh token then retry.
      for (int attempt = 0; attempt < 4; attempt++) {
        try {
          await docRef.set(user.toJson(), SetOptions(merge: true));
          final targetColl = role == AppUserRole.spectator ? 'spectators' : 'scorers';
          await _firestore.collection(targetColl).doc(uid).set(user.toJson(), SetOptions(merge: true));
          break;
        } catch (e) {
          if (attempt == 3) {
            debugPrint('Error saving user to Firestore during Google sign-up: $e');
            rethrow;
          }
          final isPermission = e is FirebaseException && e.code == 'permission-denied';
          if (isPermission) {
            debugPrint('Firestore write permission-denied (attempt $attempt), refreshing token...');
            try { await fbUser.getIdToken(true); } catch (_) {}
          }
          await Future.delayed(Duration(milliseconds: isPermission ? 800 : 500));
        }
      }

      _currentUser = user;
      return user;
    } on fa.FirebaseAuthException catch (e) {
      debugPrint('Firebase Auth Google error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('Google Sign-In service error: $e');
      if (e.toString().contains('sign_in_canceled') || e.toString().contains('12501')) {
        return null; // Treat cancellation gracefully
      }
      rethrow;
    }
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
    final data = doc.data()!;
    if (data['isDeleted'] == true) {
      await _auth.signOut();
      throw AccountDeletedException(
        'This account has been deleted. Do you wish to reactivate this account?',
        email,
        password,
      );
    }
    _currentUser = AppUser.fromJson(data);
    return _currentUser!;
  }

  @override
  Future<AppUser> reactivateAccount(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = credential.user!.uid;
    await _firestore.collection('users').doc(uid).update({
      'isDeleted': false,
    });
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) {
      throw Exception('User profile not found');
    }
    final data = doc.data()!;
    final roleStr = data['role'] as String? ?? 'spectator';
    final targetColl = roleStr == 'scorer' ? 'scorers' : 'spectators';
    try {
      await _firestore.collection(targetColl).doc(uid).update({
        'isDeleted': false,
      });
    } catch (_) {}

    _currentUser = AppUser.fromJson(data);
    return _currentUser!;
  }

  @override
  Future<void> switchToRole(AppUserRole targetRole) async {
    final fbUser = _auth.currentUser;
    final email = _currentUser?.email ?? fbUser?.email;
    if (email == null) throw Exception('No signed-in user');

    final collectionName = targetRole == AppUserRole.spectator ? 'spectators' : 'scorers';
    final querySnapshot = await _firestore.collection(collectionName).where('email', isEqualTo: email).get();

    if (querySnapshot.docs.isEmpty) {
      throw Exception('Account does not exist in target role');
    }

    if (fbUser != null) {
      await _firestore.collection('users').doc(fbUser.uid).update({
        'role': targetRole.name,
      });
    }
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(role: targetRole);
    }
  }

  @override
  Future<void> softDeleteAccount(String email, String password) async {
    final fbUser = _auth.currentUser;
    if (fbUser == null) throw Exception('No signed-in user');

    final isGoogleUser = fbUser.providerData.any((p) => p.providerId == 'google.com');
    if (isGoogleUser) {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) throw Exception('Google re-authentication cancelled');
      final googleAuth = await googleUser.authentication;
      final credential = fa.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await fbUser.reauthenticateWithCredential(credential);
    } else {
      final credential = fa.EmailAuthProvider.credential(email: email, password: password);
      await fbUser.reauthenticateWithCredential(credential);
    }

    await _firestore.collection('users').doc(fbUser.uid).update({
      'isDeleted': true,
      'deletionDate': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> signOut() async {
    debugPrint('[DEBUG] FirebaseAuthService.signOut() CALLED. Stack: ${StackTrace.current}');
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await _auth.signOut();
    _currentUser = null;
  }
}
