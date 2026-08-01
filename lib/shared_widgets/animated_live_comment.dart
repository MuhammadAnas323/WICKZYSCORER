import 'package:flutter/material.dart';
import 'package:sportyapp/data/models/comment_model.dart';
import 'package:sportyapp/theme/app_colors.dart';

class AnimatedLiveComment extends StatefulWidget {
  final CommentModel comment;
  final EdgeInsetsGeometry padding;
  final double maxWidth;
  final VoidCallback? onTap;

  const AnimatedLiveComment({
    super.key,
    required this.comment,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    this.maxWidth = 320,
    this.onTap,
  });

  @override
  State<AnimatedLiveComment> createState() => _AnimatedLiveCommentState();
}

class _AnimatedLiveCommentState extends State<AnimatedLiveComment>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.8),
      end: const Offset(0, -0.2),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 0.22),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 0.66),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 0.12),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            constraints: BoxConstraints(maxWidth: widget.maxWidth),
            padding: widget.padding,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.62),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundImage: NetworkImage(widget.comment.avatarUrl),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${widget.comment.username} ',
                          style: const TextStyle(
                            color: AppColors.floodlightGold,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                        TextSpan(
                          text: widget.comment.text,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ],
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
}
