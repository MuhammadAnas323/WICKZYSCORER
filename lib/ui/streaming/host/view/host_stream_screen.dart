import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/ui/streaming/host/viewmodel/host_stream_viewmodel.dart';

class HostStreamScreen extends ConsumerStatefulWidget {
  final String channelId;
  final String title;

  const HostStreamScreen({
    super.key,
    required this.channelId,
    this.title = 'My Live Stream',
  });

  @override
  ConsumerState<HostStreamScreen> createState() => _HostStreamScreenState();
}

class _HostStreamScreenState extends ConsumerState<HostStreamScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(hostStreamViewModelProvider.notifier).startStream(
            channelId: widget.channelId,
            title: widget.title,
            useFrontCamera: true,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hostStreamViewModelProvider);

    // ── Connecting overlay ──────────────────────────────────────────────
    if (state.isConnecting) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.pitchGreenLight),
              const SizedBox(height: 24),
              Text(
                'Starting stream...',
                style: AppTextStyles.bodyMedium(Colors.white70),
              ),
              const SizedBox(height: 8),
              Text(
                widget.title,
                style: AppTextStyles.titleLarge(Colors.white54),
              ),
            ],
          ),
        ),
      );
    }

    // ── Error state ────────────────────────────────────────────────────
    if (state.error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber_rounded,
                    color: AppColors.warning, size: 56),
                const SizedBox(height: 16),
                Text(
                  state.error!,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium(Colors.white70),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => context.pop(),
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ── Live stream UI ─────────────────────────────────────────────────
    return PopScope(
      canPop: !state.isLive,
      onPopInvokedWithResult: (didPop, _) {
        if (state.isLive && !didPop) _showEndStreamDialog();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Camera preview placeholder
            if (state.isLive)
              Container(
                color: Colors.black,
                child: const Center(
                  child: Icon(Icons.videocam, color: Colors.white24, size: 80),
                ),
              ),

            // Top overlay
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 12,
              right: 12,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: _showEndStreamDialog,
                  ),
                  const SizedBox(width: 8),
                  _LiveBadge(),
                  const SizedBox(width: 8),
                  Text(
                    _formatDuration(state.durationSeconds),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    widget.title,
                    style: AppTextStyles.labelSmall(Colors.white54),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Bottom controls
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 24,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ControlButton(
                    icon: Icons.stop_rounded,
                    color: AppColors.liveRed,
                    onTap: _showEndStreamDialog,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEndStreamDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End Stream'),
        content: const Text('Are you sure you want to end this live stream?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref
                  .read(hostStreamViewModelProvider.notifier)
                  .endStream();
              if (mounted) context.pop();
            },
            child: const Text('End Now'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }
}

class _LiveBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.liveRed,
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'LIVE',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  const _ControlButton({
    required this.icon,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color ?? Colors.white24,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}
