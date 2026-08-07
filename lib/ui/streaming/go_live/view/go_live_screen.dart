// lib/ui/streaming/go_live/view/go_live_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/core/extensions/int_extensions.dart';
import 'package:sportyapp/ui/streaming/go_live/viewmodel/active_stream_controller.dart';
import 'package:sportyapp/ui/streaming/go_live/viewmodel/go_live_viewmodel.dart';

class GoLiveScreen extends ConsumerStatefulWidget {
  const GoLiveScreen({super.key});

  @override
  ConsumerState<GoLiveScreen> createState() => _GoLiveScreenState();
}

class _GoLiveScreenState extends ConsumerState<GoLiveScreen>
    with SingleTickerProviderStateMixin {
  bool _cameraStarted = false;
  bool _streamStarted = false;

  // ── Zoom ─────────────────────────────────────────────────────────────────
  double _baseZoom = 1.0;
  double _currentZoom = 1.0;
  static const double _maxZoom = 5.0;

  // ── Comment reply ─────────────────────────────────────────────────────────
  final _commentCtrl = TextEditingController();
  final _commentFocus = FocusNode();
  String? _replyToUsername;
  bool _showCommentInput = false;

  // ── Animation ─────────────────────────────────────────────────────────────
  late AnimationController _liveIndicatorController;
  late Animation<double> _liveIndicatorAnimation;

  @override
  void initState() {
    super.initState();
    _liveIndicatorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _liveIndicatorAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(
          parent: _liveIndicatorController, curve: Curves.easeInOut),
    );
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initAndStartStream());
  }

  @override
  void dispose() {
    _liveIndicatorController.dispose();
    _commentCtrl.dispose();
    _commentFocus.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  Future<void> _initAndStartStream() async {
    if (_cameraStarted) return;
    _cameraStarted = true;
    final controller = ref.read(goLiveViewModelProvider);
    await controller.initCamera(useFrontCamera: true);
    if (!mounted) return;
    if (!_streamStarted) {
      _streamStarted = true;
      await controller.startStream();
    }
  }

  // ── Pinch-to-zoom ─────────────────────────────────────────────────────────

  void _onScaleStart(ScaleStartDetails _) {}

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (d.pointerCount < 2) return;
    final newZoom = (_baseZoom * d.scale).clamp(1.0, _maxZoom);
    if (mounted) setState(() => _currentZoom = newZoom);
  }

  void _onScaleEnd(ScaleEndDetails _) => _baseZoom = _currentZoom;

  // ── Reply to comments ─────────────────────────────────────────────────────

  void _startReply(String username) {
    setState(() {
      _replyToUsername = username;
      _showCommentInput = true;
      _commentCtrl.text = '@$username ';
      _commentCtrl.selection = TextSelection.fromPosition(
          TextPosition(offset: _commentCtrl.text.length));
    });
    _commentFocus.requestFocus();
  }

  void _sendComment() {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    ref.read(goLiveViewModelProvider).sendComment(text);
    setState(() {
      _replyToUsername = null;
      _commentCtrl.clear();
    });
    _commentFocus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(goLiveStateProvider);

    return GestureDetector(
      onScaleStart: _onScaleStart,
      onScaleUpdate: _onScaleUpdate,
      onScaleEnd: _onScaleEnd,
      onTap: () {
        if (_showCommentInput) {
          setState(() => _showCommentInput = false);
          _commentFocus.unfocus();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: state.summary != null
            ? _buildSummary(context, state)
            : Stack(
                fit: StackFit.expand,
                children: [
                  // ── Camera Preview ──────────────────────────────────
                  _buildCameraPreview(),

                  // ── Zoom indicator ──────────────────────────────────
                  if (_currentZoom > 1.05)
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 60,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_currentZoom.toStringAsFixed(1)}\u00d7',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),

                  // ── Connecting Overlay ──────────────────────────────
                  if (state.isConnecting) _buildConnectingOverlay(),

                  // ── Top Overlay ─────────────────────────────────────
                  if (!state.isConnecting) _buildTopOverlay(context, state),

                  // ── Floating comments feed ──────────────────────────
                  if (!state.isConnecting && state.comments.isNotEmpty)
                    _buildCommentsFeed(state),

                  // ── Bottom Controls ─────────────────────────────────
                  if (!state.isConnecting) _buildBottomControls(context, state),

                  // ── Comment reply input ─────────────────────────────
                  if (_showCommentInput) _buildCommentInput(context),
                ],
              ),
      ),
    );
  }

  // ── Camera Preview ────────────────────────────────────────────────────────

  Widget _buildCameraPreview() {
    return Positioned.fill(
      child: Container(
        color: Colors.black,
        child: const Center(
          child: Icon(Icons.videocam, color: Colors.white12, size: 80),
        ),
      ),
    );
  }

  // ── Connecting Overlay ────────────────────────────────────────────────────

  Widget _buildConnectingOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppColors.pitchGreenLight,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Connecting to stream...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Connecting to stream...',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top Overlay ───────────────────────────────────────────────────────────

  Widget _buildTopOverlay(BuildContext context, ActiveStreamState state) {
    final topPad = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPad + 8,
      left: 16,
      right: 16,
      child: Row(
        children: [
          // Close / back button
          GestureDetector(
            onTap: () => _handleClose(context, state),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 10),

          // LIVE badge + timer
          if (state.isLive) ...[
            _buildLiveBadge(state),
            const SizedBox(width: 10),
          ],

          const Spacer(),

          // Viewer count
          if (state.isLive) _buildViewerCount(state),
        ],
      ),
    );
  }

  Widget _buildLiveBadge(ActiveStreamState state) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pulsing red dot
        AnimatedBuilder(
          animation: _liveIndicatorAnimation,
          builder: (_, __) => Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  AppColors.liveRed.withOpacity(_liveIndicatorAnimation.value),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.liveRed,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text(
            'LIVE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Timer (starts only after isLive = true)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            state.durationSeconds.toHMS,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildViewerCount(ActiveStreamState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.remove_red_eye_outlined,
              color: Colors.white70, size: 14),
          const SizedBox(width: 4),
          Text(
            '${state.viewerCount}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }



  // ── Bottom Controls ─────────────────────────────────────────────────────

  Widget _buildBottomControls(BuildContext context, ActiveStreamState state) {
    final controller = ref.read(goLiveViewModelProvider);
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Positioned(
      bottom: bottomPad + 16,
      left: 16,
      right: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Controls row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Mute / Unmute
              _buildControlButton(
                icon: state.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                label: state.isMuted ? 'Unmute' : 'Mute',
                onTap: () => controller.toggleMute(),
              ),

              // Flip Camera — also resets zoom
              _buildControlButton(
                icon: Icons.flip_camera_ios_rounded,
                label: 'Flip',
                onTap: () async {
                  await controller.switchCamera();
                  if (mounted) setState(() => _currentZoom = 1.0);
                },
              ),

              // Zoom reset (tap to reset; pinch to zoom)
              _buildControlButton(
                icon: _currentZoom > 1.05
                    ? Icons.zoom_out_rounded
                    : Icons.zoom_in_rounded,
                label: _currentZoom > 1.05 ? 'Reset' : 'Zoom',
                onTap: () {
                  if (_currentZoom > 1.05) {
                    if (mounted) setState(() => _currentZoom = 1.0);
                    _baseZoom = 1.0;
                  }
                },
              ),

              // Chat toggle
              _buildControlButton(
                icon: _showCommentInput
                    ? Icons.chat_bubble_rounded
                    : Icons.chat_bubble_outline_rounded,
                label: 'Chat',
                onTap: () {
                  setState(() => _showCommentInput = !_showCommentInput);
                  if (_showCommentInput) {
                    Future.delayed(
                      const Duration(milliseconds: 80),
                      () => _commentFocus.requestFocus(),
                    );
                  } else {
                    _commentFocus.unfocus();
                  }
                },
              ),

              // More
              _buildControlButton(
                icon: Icons.more_horiz_rounded,
                label: 'More',
                onTap: () {}, // reserved
              ),
            ],
          ),
          const SizedBox(height: 16),

          // End Live button — large, red, always visible
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: () => _showEndConfirmDialog(context),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE53935), Color(0xFFC62828)],
                  ),
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.liveRed.withOpacity(0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.stop_circle_outlined,
                        color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'End Live',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white12),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── Floating comments feed (tap a comment to reply) ───────────────────────

  Widget _buildCommentsFeed(ActiveStreamState state) {
    return Positioned(
      bottom: 200,
      left: 12,
      right: 80,
      child: SizedBox(
        height: 180,
        child: ShaderMask(
          shaderCallback: (rect) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black],
            stops: [0.0, 0.5],
          ).createShader(rect),
          blendMode: BlendMode.dstIn,
          child: ListView.builder(
            reverse: true,
            itemCount: state.comments.length,
            itemBuilder: (context, i) {
              final comment = state.comments[i];
              return GestureDetector(
                onTap: () => _startReply(comment.username),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: RichText(
                    text: TextSpan(children: [
                      TextSpan(
                        text: '${comment.username} ',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.floodlightGold,
                            fontSize: 12),
                      ),
                      TextSpan(
                        text: comment.text,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ]),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ── Comment reply input panel ─────────────────────────────────────────────

  Widget _buildCommentInput(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Positioned(
      bottom: bottomPad,
      left: 0,
      right: 0,
      child: Material(
        color: const Color(0xFF1A1A1A),
        child: Padding(
          padding: EdgeInsets.only(
            left: 12,
            right: 12,
            top: 10,
            bottom: MediaQuery.of(context).viewInsets.bottom + 10,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Reply-to banner
              if (_replyToUsername != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.reply_rounded,
                          color: AppColors.floodlightGold, size: 14),
                      const SizedBox(width: 6),
                      Text('Replying to @$_replyToUsername',
                          style: const TextStyle(
                              color: AppColors.floodlightGold, fontSize: 12)),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => setState(() {
                          _replyToUsername = null;
                          _commentCtrl.clear();
                        }),
                        child: const Icon(Icons.close,
                            color: Colors.white38, size: 14),
                      ),
                    ],
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _commentCtrl,
                        focusNode: _commentFocus,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: 'Say something...',
                          hintStyle:
                              TextStyle(color: Colors.white38, fontSize: 13),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                        ),
                        onSubmitted: (_) => _sendComment(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sendComment,
                    child: Container(
                      padding: const EdgeInsets.all(11),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                            colors: [Color(0xFF2ECC71), Color(0xFF1A7A3E)]),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── End / close actions ───────────────────────────────────────────────────

  void _handleClose(BuildContext context, ActiveStreamState state) {
    if (state.isLive) {
      // Minimise and go back (stream continues in background)
      ref.read(goLiveViewModelProvider).minimizeStream();
      context.go('/home');
    } else {
      ref.read(goLiveViewModelProvider).reset();
      context.pop();
    }
  }

  void _showEndConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'End Live Stream?',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        content: const Text(
          'This will stop your live stream. Viewers will be disconnected.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white54, fontSize: 15)),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.liveRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text(
              'End Live',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(goLiveViewModelProvider).endStream();
              if (context.mounted) {
                context.go('/home');
              }
            },
          ),
        ],
      ),
    );
  }

  // ── Stream summary screen ─────────────────────────────────────────────────

  Widget _buildSummary(BuildContext context, ActiveStreamState state) {
    final sum = state.summary!;
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.pitchGreenLight.withOpacity(0.15),
                  ),
                  child: const Icon(Icons.check_circle_outline_rounded,
                      color: AppColors.pitchGreenLight, size: 44),
                ),
                const SizedBox(height: 20),
                const Text(
                  '🏁  Stream Ended',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 24),
                _summaryTile(
                    icon: Icons.timer_outlined,
                    label: 'Duration',
                    value: sum.duration.inSeconds.toHMS),
                const Divider(color: Colors.white12),
                _summaryTile(
                    icon: Icons.people_outline_rounded,
                    label: 'Peak Viewers',
                    value: sum.peakViewers.toString()),
                const Divider(color: Colors.white12),
                _summaryTile(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'Comments',
                    value: sum.totalComments.toString()),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.pitchGreenLight,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50)),
                    ),
                    onPressed: () {
                      ref.read(goLiveViewModelProvider).reset();
                      context.go('/home');
                    },
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _summaryTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38, size: 20),
          const SizedBox(width: 12),
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 14)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              )),
        ],
      ),
    );
  }
}
