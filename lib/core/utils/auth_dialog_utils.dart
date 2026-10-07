// lib/core/utils/auth_dialog_utils.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sportyapp/core/extensions/string_extensions.dart';
import 'package:sportyapp/core/providers/auth_provider.dart';
import 'package:sportyapp/core/utils/app_error_handler.dart';
import 'package:sportyapp/data/services/auth_service.dart';
import 'package:sportyapp/theme/app_colors.dart';

Future<void> handleSignInException(
  BuildContext context,
  WidgetRef ref,
  Object e, {
  required VoidCallback onSuccess,
}) async {
  if (e is AccountDeletedException) {
    final reactivate = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Account Deleted'.toTitleCase),
        content: Text(e.message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel'.toTitleCase),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.pitchGreen,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Reactivate'.toTitleCase),
          ),
        ],
      ),
    );

    if (reactivate == true) {
      try {
        await ref.read(currentUserProvider.notifier).reactivateAccount(e.email, e.password);
        if (context.mounted) {
          onSuccess();
        }
      } catch (ex) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppErrorHandler.getUserFriendlyMessage(ex)),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  } else {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppErrorHandler.getUserFriendlyMessage(e)),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
}
