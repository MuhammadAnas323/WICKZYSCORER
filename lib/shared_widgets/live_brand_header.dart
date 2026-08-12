import 'package:flutter/material.dart';
import 'package:sportyapp/theme/app_colors.dart';

class LiveBrandHeader extends StatelessWidget {
  final String appName;
  final String appLogoUrl;
  final String? streamName;
  final String? broadcasterName;
  final bool showLiveBadge;
  final int? viewerCount;
  final bool compact;
  final EdgeInsetsGeometry? padding;
  final Widget? trailing;

  const LiveBrandHeader({
    super.key,
    this.appName = 'WickzyScorer',
    this.appLogoUrl = 'assets/images/Crixora.png',
    this.streamName,
    this.broadcasterName,
    this.showLiveBadge = false,
    this.viewerCount,
    this.compact = false,
    this.padding,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        final logoSize = compact
            ? (maxWidth < 260 ? 22.0 : 28.0)
            : (maxWidth < 280 ? 28.0 : 36.0);
        final textScale = maxWidth < 280 ? 0.92 : 1.0;

        return Container(
          padding: padding ??
              EdgeInsets.symmetric(
                horizontal: compact ? 10 : 12,
                vertical: compact ? 8 : 10,
              ),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.55),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: logoSize,
                height: logoSize,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _buildLogo(logoSize),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              appName,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: (compact ? 13 : 15) * textScale,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        if (showLiveBadge) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.liveRed,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'LIVE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.7,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (streamName != null && streamName!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        streamName!,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: (compact ? 11 : 12) * textScale,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (broadcasterName != null &&
                        broadcasterName!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        broadcasterName!,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: (compact ? 10 : 11) * textScale,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (viewerCount != null) ...[
                const SizedBox(width: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.remove_red_eye_outlined,
                            size: 12, color: Colors.white70),
                        const SizedBox(width: 4),
                        Text(
                          '$viewerCount',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildLogo(double size) {
    if (appLogoUrl.startsWith('http')) {
      return Image.network(
        appLogoUrl,
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) => _fallbackLogo(size),
      );
    }

    if (appLogoUrl.startsWith('assets/')) {
      return Image.asset(
        appLogoUrl,
        width: size,
        height: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) => _fallbackLogo(size),
      );
    }

    return _fallbackLogo(size);
  }

  Widget _fallbackLogo(double size) {
    return Container(
      width: size,
      height: size,
      color: AppColors.pitchGreen,
      child: Icon(Icons.sports_cricket, color: Colors.white, size: size * 0.6),
    );
  }
}
