import 'package:ayyam/design/components/pressable.dart';
import 'package:ayyam/design/theme/nocturne_theme.dart';
import 'package:ayyam/design/tokens/nocturne_tokens.dart';
import 'package:flutter/widgets.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(NocturneSpace.x5),
    this.radius = NocturneRadius.card,
    this.tint,
    this.glow = false,
    this.onTap,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? tint;
  final bool glow;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    final tone = NocturneScope.toneOf(context);
    final glowColor = tint ?? NocturneGradients.glowFor(tone, theme);
    final borderRadius = BorderRadius.circular(radius);

    final card = ClipRRect(
      borderRadius: borderRadius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          border: Border.all(color: theme.line, width: 1),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[theme.glassStrong, theme.glass],
          ),
        ),
        child: Stack(
          children: <Widget>[
            Positioned(
              left: radius * 0.5,
              right: radius * 0.5,
              top: 0,
              height: 1,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[
                      Color(0x00FFFFFF),
                      Color(0x66FFFFFF),
                      Color(0x00FFFFFF),
                    ],
                  ),
                ),
              ),
            ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );

    Widget surface = card;
    if (glow) {
      surface = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: glowColor.withValues(alpha: 0.16),
              blurRadius: 48,
              spreadRadius: -12,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: surface,
      );
    }

    if (onTap == null) return surface;
    return Pressable(
      onTap: onTap,
      semanticLabel: semanticLabel,
      scale: 0.985,
      child: surface,
    );
  }
}
