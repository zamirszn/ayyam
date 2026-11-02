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

    final card = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: glow
            ? <BoxShadow>[
                BoxShadow(
                  color: glowColor.withValues(alpha: 0.16),
                  blurRadius: 48,
                  spreadRadius: -12,
                  offset: const Offset(0, 20),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            border: Border.all(color: theme.line),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[theme.glassStrong, theme.glass],
            ),
          ),
          child: Stack(
            children: <Widget>[
              Positioned(
                left: 18,
                right: 18,
                top: 0,
                height: 1,
                child: ColoredBox(color: theme.lineStrong),
              ),
              Padding(padding: padding, child: child),
            ],
          ),
        ),
      ),
    );

    if (onTap == null) return card;
    return Pressable(onTap: onTap, semanticLabel: semanticLabel, child: card);
  }
}
