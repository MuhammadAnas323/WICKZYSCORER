import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';

class AppErrorHandler {
  static String getUserFriendlyMessage(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'email-already-in-use':
          return 'This email address is already in use by another account.';
        case 'invalid-email':
          return 'The email address is invalid.';
        case 'operation-not-allowed':
          return 'This sign-in method is disabled.';
        case 'weak-password':
          return 'The password provided is too weak.';
        case 'user-disabled':
          return 'This user account has been disabled.';
        case 'user-not-found':
          return 'No user found with this email.';
        case 'wrong-password':
          return 'Incorrect password. Please try again.';
        case 'invalid-credential':
          return 'Invalid credentials. Please check your email and password.';
        case 'network-request-failed':
          return 'A network error occurred. Please check your internet connection.';
        case 'too-many-requests':
          return 'Too many requests. Please try again later.';
        default:
          return e.message ?? 'An authentication error occurred. Please try again.';
      }
    }

    if (e is FirebaseException) {
      switch (e.code) {
        case 'permission-denied':
          return 'You do not have permission to perform this action.';
        case 'unavailable':
          return 'The service is currently unavailable. Please check your connection and try again.';
        case 'not-found':
          return 'The requested resource was not found.';
        default:
          return e.message ?? 'A database error occurred. Please try again.';
      }
    }

    if (e is PlatformException) {
      if (e.code == 'sign_in_failed' || e.code == '12501' || e.code == 'sign_in_canceled') {
        return 'Google Sign-In was cancelled.';
      }
      if (e.code == 'network_error') {
        return 'A network error occurred. Please check your internet connection.';
      }
      return e.message ?? 'A platform error occurred. Please try again.';
    }

    if (e is Exception) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('cancelled') || msg.contains('canceled')) {
        return 'Sign-in was cancelled.';
      }
    }

    if (e is SocketException) {
      return 'No internet connection. Please connect to a network and try again.';
    }

    if (e is FormatException) {
      return 'Data format error. Please try again.';
    }

    final eString = e.toString();
    if (eString.contains('SocketException') || eString.contains('network_error')) {
      return 'No internet connection. Please check your network and try again.';
    }

    // Default generic error
    return 'An unexpected error occurred. Please try again.';
  }
}
