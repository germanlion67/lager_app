// lib/widgets/app_loading_overlay.dart
//
// M-004: Zentrales Loading-Overlay Widget.
// Wird in allen Screens einheitlich verwendet.

import 'package:flutter/material.dart';
import '../config/app_config.dart';

/// Halbtransparentes Overlay das den gesamten Screen blockiert.
/// Verhindert Nutzerinteraktion während asynchroner Operationen.
///
/// Verwendung:
/// ```dart
/// Stack(
///   children: [
///     MeinScreenInhalt(),
///     if (_isLoading) const AppLoadingOverlay(),
///   ],
/// )
/// ```
class AppLoadingOverlay extends StatelessWidget {
  /// Optionaler Text unter dem Spinner (z. B. 'Speichern...')
  final String? message;

  const AppLoadingOverlay({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ColoredBox(
      color: colorScheme.scrim.withValues(alpha: AppConfig.overlayOpacity),
      child: Center(
        child: Card(
          elevation: AppConfig.cardElevationHigh,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConfig.borderRadiusMedium),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConfig.spacingXXLarge,
              vertical: AppConfig.spacingXLarge,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                if (message != null) ...[
                  const SizedBox(height: AppConfig.spacingMedium),
                  Text(
                    message!,
                    style: textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline-Ladeindikator für Listen und kleinere Bereiche.
/// Ersetzt den einfachen [CircularProgressIndicator] in Listen-Screens.
class AppLoadingIndicator extends StatelessWidget {
  final String? message;

  const AppLoadingIndicator({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: AppConfig.spacingMedium),
            Text(
              message!,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Skeleton-Tile für die Artikelliste während des Ladens.
/// Simuliert die Form eines [ListTile] mit animiertem Shimmer-Effekt.
class ArtikelSkeletonTile extends StatefulWidget {
  const ArtikelSkeletonTile({super.key});

  @override
  State<ArtikelSkeletonTile> createState() => _ArtikelSkeletonTileState();
}

class _ArtikelSkeletonTileState extends State<ArtikelSkeletonTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppConfig.skeletonAnimationDuration,
    )..repeat(reverse: true);

    _animation = Tween<double>(
      begin: AppConfig.skeletonOpacityMin,
      end: AppConfig.skeletonOpacityMax,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final skeletonColor = colorScheme.onSurface.withValues(
          alpha: _animation.value,
        );

        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConfig.spacingMedium,
            vertical: AppConfig.spacingSmall,
          ),
          child: Row(
            children: [
              // Bild-Platzhalter
              Container(
                width: AppConfig.skeletonLeadingSize,
                height: AppConfig.skeletonLeadingSize,
                decoration: BoxDecoration(
                  color: skeletonColor,
                  borderRadius: BorderRadius.circular(
                    AppConfig.borderRadiusXSmall,
                  ),
                ),
              ),
              const SizedBox(width: AppConfig.spacingMedium),
              // Text-Platzhalter
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Titel
                    Container(
                      height: AppConfig.skeletonTitleHeight,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: skeletonColor,
                        borderRadius: BorderRadius.circular(
                          AppConfig.borderRadiusXXSmall,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppConfig.spacingXSmall),
                    // Artikelnummer
                    Container(
                      height: AppConfig.skeletonSubtitleHeight,
                      width: AppConfig.skeletonSubtitleWidth,
                      decoration: BoxDecoration(
                        color: skeletonColor,
                        borderRadius: BorderRadius.circular(
                          AppConfig.borderRadiusXXSmall,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppConfig.spacingXSmall),
                    // Ort • Fach
                    Container(
                      height: AppConfig.skeletonSubtitleHeight,
                      width: AppConfig.skeletonOrtFachWidth,
                      decoration: BoxDecoration(
                        color: skeletonColor,
                        borderRadius: BorderRadius.circular(
                          AppConfig.borderRadiusXXSmall,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Zeigt [count] Skeleton-Tiles als Lade-Platzhalter.
class ArtikelSkeletonList extends StatelessWidget {
  final int count;

  const ArtikelSkeletonList({super.key, this.count = 8});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, __) => const ArtikelSkeletonTile(),
    );
  }
}

/// Button mit integriertem Lade-Spinner.
/// Ersetzt alle manuellen `_isSaving ? CircularProgressIndicator : Icon`
/// Konstrukte in den Screens.
///
/// Verwendung:
/// ```dart
/// AppLoadingButton(
///   isLoading: _isSaving,
///   onPressed: _save,
///   label: 'Speichern',
///   icon: Icons.save,
///   loadingLabel: 'Speichern...',
/// )
/// ```
class AppLoadingButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;
  final String label;
  final String? loadingLabel;
  final IconData? icon;

  const AppLoadingButton({
    super.key,
    required this.isLoading,
    required this.onPressed,
    required this.label,
    this.loadingLabel,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: isLoading ? null : onPressed,
      icon: isLoading
          ? const SizedBox(
              width: AppConfig.iconSizeSmall,
              height: AppConfig.iconSizeSmall,
              child: CircularProgressIndicator(
                strokeWidth: AppConfig.strokeWidthMedium,
              ),
            )
          : Icon(icon ?? Icons.check),
      label: Text(isLoading ? (loadingLabel ?? label) : label),
    );
  }
}