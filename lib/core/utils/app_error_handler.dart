import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

class AppErrorHandler {
  static String getUserFriendlyMessage(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'email-already-in-use':
          return 'This email address is already in use by another account.';
        case 'invalid-email':
          return 'Please, email address is not correct';
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
          final cleanMsg = e.message;
          if (cleanMsg != null && cleanMsg.isNotEmpty && !cleanMsg.contains('[')) {
            return cleanMsg;
          }
          return 'An authentication error occurred. Please try again.';
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
          final cleanMsg = e.message;
          if (cleanMsg != null && cleanMsg.isNotEmpty && !cleanMsg.contains('[')) {
            return cleanMsg;
          }
          return 'A database error occurred. Please try again.';
      }
    }

    if (e is PlatformException) {
      if (e.code == 'sign_in_canceled' || e.code == '12501') {
        return 'Sign-in was cancelled.';
      }
      if (e.code == 'sign_in_failed' || e.code == '10' || e.code == '12500') {
        return 'Google Sign-In failed. Please verify Google Play Services and your configuration.';
      }
      if (e.code == 'network_error') {
        return 'A network error occurred. Please check your internet connection.';
      }
      return e.message ?? 'A platform error occurred. Please try again.';
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

    if (eString.contains('cancelled') || eString.contains('canceled')) {
      return 'Sign-in was cancelled.';
    }

    if (eString.startsWith('Exception: ')) {
      final msg = eString.substring(11).trim();
      if (msg.isNotEmpty && !msg.contains('Instance of') && !msg.contains('Stack trace')) {
        return msg;
      }
    }

    // Default generic error
    return 'An unexpected error occurred. Please try again.';
  }
}
