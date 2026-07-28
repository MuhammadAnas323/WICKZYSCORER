import 'package:flutter/material.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';
import 'package:sportyapp/data/models/player_model.dart';

/// Player avatar circle with flag emoji overlay + name below.
class PlayerAvatar extends StatelessWidget {
  final PlayerModel player;
  final double size;
  final VoidCallback? onTap;

  const PlayerAvatar({
    super.key,
    required this.player,
    this.size = 56,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size + 16,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: size / 2,
                  backgroundColor: AppColors.pitchGreen.withValues(alpha: 0.15),
                  backgroundImage: NetworkImage(player.imageUrl),
                  onBackgroundImageError: (_, __) {},
                  child: Text(player.shortName[0],
                    style: AppTextStyles.titleMedium(cs.primary)),
                ),
                Positioned(
                  bottom: -2, right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Text(player.teamFlag, style: const TextStyle(fontSize: 10)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(player.shortName,
              style: AppTextStyles.labelSmall(cs.onSurface),
              overflow: TextOverflow.ellipsis, maxLines: 1, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
