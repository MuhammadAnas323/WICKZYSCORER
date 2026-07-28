// lib/ui/streaming/live_viewer/view/live_viewer_screen.dart
//
// Full-screen live viewer screen.
// Shows the broadcaster's camera feed via AgoraVideoView (remote video).
// FIX: Uses VideoSourceType.videoSourceRemote explicitly so the remote video
// renders correctly instead of showing a black screen.

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sportyapp/data/models/stream_model.dart';
import 'package:sportyapp/data/providers/agora_providers.dart';
import 'package:sportyapp/data/services/agora_service.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/ui/streaming/live_viewer/viewmodel/live_viewer_viewmodel.dart';
import 'package:sportyapp/shared_widgets/error_state.dart';

class LiveViewerScreen extends ConsumerStatefulWidget {
  final String streamId;
  const LiveViewerScreen({super.key, required this.streamId});

  @override
  ConsumerState<LiveViewerScreen> createState() => _LiveViewerScreenState();
}

class _LiveViewerScreenState extends ConsumerState<LiveViewerScreen>
    with SingleTickerProviderStateMixin {
  final _commentCtrl = TextEditingController();
  bool _statsAttached = false;
  bool _showChat = false;
  VideoViewController? _remoteViewController;
  late AnimationController _liveIndicatorController;
  late Animation<double> _liveIndicatorAnimation;

  @override
  void initState() {
    super.initState();

    // Pulsing LIVE badge animation
    _liveIndicatorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _liveIndicatorAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(
          parent: _liveIndicatorController, curve: Curves.easeInOut),
    );

    // Full-screen immersive for better experience
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _remoteViewController?.dispose();
    _commentCtrl.dispose();
    _liveIndicatorController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // ── Remote video view ─────────────────────────────────────────────────────

  Widget _buildVideoView(LiveViewerState state) {
    final agora = ref.read(agoraServiceProvider);

    if (!_statsAttached) {
      _statsAttached = true;
      agora.attachStats(ref.read(liveStreamStatsProvider.notifier));
    }

    // Show the remote camera feed when broadcaster is present
    if (state.hasJoinedAgora &&
        state.remoteUids.isNotEmpty &&
        state.stream?.channelName != null) {
      final stream = state.stream!;

      final sourceType = stream.videoSourceType == VideoSourceTypeEnum.screen
          ? VideoSourceType.videoSourceScreenPrimary
          : VideoSourceType.videoSourceRemote;

      _remoteViewController ??= agora.remoteViewController(
        state.remoteUids.first,
        stream.channelName!,
        sourceType: sourceType,
      );

      return Positioned.fill(
        child: AgoraVideoView(controller: _remoteViewController!),
      );
    }

    // Show loading / waiting state
    return _buildWaitingView(state);
  }

  Widget _buildWaitingView(LiveViewerState state) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (state.hasJoinedAgora) ...[
              // Joined but no remote video yet — broadcaster is still connecting
              SizedBox(
                width: 56,
                height: 56,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.pitchGreenLight,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Connecting to broadcaster...',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 6),
              const Text(
                'The stream will begin shortly',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ] else if (state.isReconnecting) ...[
              const Icon(Icons.wifi_off_rounded,
                  color: Colors.white38, size: 48),
              const SizedBox(height: 12),
              const Text(
                'Reconnecting...',
                style: TextStyle(color: Colors.white54, fontSize: 15),
              ),
            ] else ...[
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.pitchGreenLight,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Joining live stream...',
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(liveViewerViewModelProvider(widget.streamId));

    if (state.isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.pitchGreenLight),
        ),
      );
    }

    if (state.error != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: ErrorState(
          message: state.error!,
          onRetry: () => ref
              .read(liveViewerViewModelProvider(widget.streamId).notifier)
              .load(),
        ),
      );
    }

    final stream = state.stream!;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Full-screen video ──────────────────────────────────────────
          _buildVideoView(state),

          // ── Top overlay ────────────────────────────────────────────────
          _buildTopOverlay(context, stream, state),

          // ── Bottom chat / controls overlay ────────────────────────────
          _buildBottomOverlay(context, stream, state),

          // ── Reconnecting banner ────────────────────────────────────────
          if (state.isReconnecting) _buildReconnectingBanner(),
        ],
      ),
    );
  }

  // ── Top overlay ───────────────────────────────────────────────────────────

  Widget _buildTopOverlay(
      BuildContext context, StreamModel stream, LiveViewerState state) {
    final topPad = MediaQuery.of(context).padding.top;
    return Positioned(
      top: topPad + 8,
      left: 12,
      right: 12,
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 10),

          // Broadcaster avatar + name
          CircleAvatar(
            radius: 18,
            backgroundImage: NetworkImage(stream.broadcasterAvatar),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  stream.broadcasterName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                Text(
                  stream.title,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // LIVE badge
          _buildLiveBadge(),
          const SizedBox(width: 8),

          // Viewer count
          _buildViewerBadge(stream.viewerCount),
        ],
      ),
    );
  }

  Widget _buildLiveBadge() {
    return AnimatedBuilder(
      animation: _liveIndicatorAnimation,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.liveRed
                  .withOpacity(_liveIndicatorAnimation.value),
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
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
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewerBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.remove_red_eye_outlined,
              color: Colors.white70, size: 12),
          const SizedBox(width: 3),
          Text(
            '$count',
            style: const TextStyle(
                color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // ── Bottom overlay ────────────────────────────────────────────────────────

  Widget _buildBottomOverlay(
      BuildContext context, StreamModel stream, LiveViewerState state) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Positioned(
      bottom: bottomPad,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withOpacity(0.85), Colors.transparent],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Comments feed
            if (_showChat) _buildCommentsFeed(state),

            // Input row
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  // Toggle chat
                  GestureDetector(
                    onTap: () => setState(() => _showChat = !_showChat),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _showChat
                            ? Icons.chat_bubble_rounded
                            : Icons.chat_bubble_outline_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Comment input
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _commentCtrl,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: 'Say something...',
                          hintStyle:
                              TextStyle(color: Colors.white38, fontSize: 13),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                        ),
                        onSubmitted: (val) {
                          ref
                              .read(liveViewerViewModelProvider(widget.streamId)
                                  .notifier)
                              .sendComment(val);
                          _commentCtrl.clear();
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Send button
                  GestureDetector(
                    onTap: () {
                      ref
                          .read(liveViewerViewModelProvider(widget.streamId)
                              .notifier)
                          .sendComment(_commentCtrl.text);
                      _commentCtrl.clear();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2ECC71), Color(0xFF1A7A3E)],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentsFeed(LiveViewerState state) {
    if (state.comments.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 200,
      child: ShaderMask(
        shaderCallback: (rect) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black],
          stops: [0.0, 0.45],
        ).createShader(rect),
        blendMode: BlendMode.dstIn,
        child: ListView.builder(
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: state.comments.length,
          itemBuilder: (ctx, i) {
            final c = state.comments[i];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundImage: NetworkImage(c.avatarUrl),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RichText(
                      text: TextSpan(children: [
                        TextSpan(
                          text: '${c.username} ',
                          style: const TextStyle(
                            color: AppColors.floodlightGold,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        TextSpan(
                          text: c.text,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12),
                        ),
                      ]),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Reconnecting banner ───────────────────────────────────────────────────

  Widget _buildReconnectingBanner() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        color: AppColors.warning.withOpacity(0.9),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.black,
              ),
            ),
            SizedBox(width: 8),
            Text(
              'Reconnecting to stream...',
              style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                  fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
