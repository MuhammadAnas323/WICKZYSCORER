// lib/ui/scorer/shared/widgets/cloud_error_toast.dart
// Surfaces Firestore write failures on EVERY screen (not just the scorer
// shell), so a tournament/match that failed to sync is never silent. Mounted
// once at the app root via MaterialApp.router.builder.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sportyapp/data/repositories/scorer_repository.dart';

class CloudErrorToast extends ConsumerStatefulWidget {
  const CloudErrorToast({super.key});

  @override
  ConsumerState<CloudErrorToast> createState() => _CloudErrorToastState();
}

class _CloudErrorToastState extends ConsumerState<CloudErrorToast> {
  @override
  void initState() {
    super.initState();
    ref.read(scorerRepositoryProvider).lastCloudError.addListener(_onError);
  }

  void _onError() {
    final err = ref.read(scorerRepositoryProvider).lastCloudError.value;
    if (err == null || !mounted) return;
    ref.read(scorerRepositoryProvider).clearCloudError();
    final isPermission = err.toLowerCase().contains('permission') ||
        err.toLowerCase().contains('denied') ||
        err.toLowerCase().contains('forbidden');
    // Ownership checks were removed and writes are open to signed-in users, so
    // a permission error here is expected to be a false alarm (e.g. stale
    // rules). Only surface true failure conditions (network, missing config).
    final friendly = isPermission
        ? 'Could not sync to the cloud. Changes are saved on this device only.'
        : 'Could not sync to the cloud ($err). Changes are saved on this device only.';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(friendly),
          backgroundColor: const Color(0xFFB3261E),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  void dispose() {
    ref.read(scorerRepositoryProvider).lastCloudError.removeListener(_onError);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
