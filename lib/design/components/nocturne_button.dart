import 'package:ayyam/design/components/nocturne_icon.dart';
import 'package:ayyam/design/components/pressable.dart';
import 'package:ayyam/design/theme/nocturne_theme.dart';
import 'package:ayyam/design/tokens/nocturne_tokens.dart';
import 'package:ayyam/design/type/nocturne_type.dart';
import 'package:flutter/widgets.dart';

enum NocturneButtonStyle { signal, ink, glass, danger }

class NocturneButton extends StatelessWidget {
  const NocturneButton({
    super.key,
    required this.label,
    required this.onTap,
    this.style = NocturneButtonStyle.signal,
    this.trailing,
    this.expand = true,
    this.compact = false,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onTap;
  final NocturneButtonStyle style;
  final NocturneGlyph? trailing;
  final bool expand;
  final bool compact;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    final (background, foreground, border) = switch (style) {
      NocturneButtonStyle.signal => (theme.accent, theme.canvas, null),
      NocturneButtonStyle.ink => (theme.ink, theme.canvas, null),
      NocturneButtonStyle.glass => (theme.glassStrong, theme.ink, theme.line),
      NocturneButtonStyle.danger => (
        theme.missed.withValues(alpha: 0.16),
        theme.missed,
        theme.missed.withValues(alpha: 0.35),
      ),
    };

    final button = SizedBox(
      height: compact ? 44 : 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(NocturneRadius.pill),
          border: border == null ? null : Border.all(color: border, width: 1),
          boxShadow: style == NocturneButtonStyle.signal
              ? <BoxShadow>[
                  BoxShadow(
                    color: theme.accent.withValues(
                      alpha: onTap == null ? 0 : 0.28,
                    ),
                    blurRadius: 24,
                    spreadRadius: -4,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: NocturneSpace.x5),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: NocturneType.bodyStrong(foreground),
                ),
              ),
              if (trailing case final glyph?) ...<Widget>[
                const SizedBox(width: NocturneSpace.x3),
                NocturneIcon(glyph, size: 19, color: foreground),
              ],
            ],
          ),
        ),
      ),
    );

    return Opacity(
      opacity: onTap == null ? 0.45 : 1,
      child: Pressable(
        onTap: onTap,
        semanticLabel: semanticLabel ?? label,
        scale: 0.975,
        child: expand
            ? SizedBox(width: double.infinity, child: button)
            : button,
      ),
    );
  }
}

class CircleAction extends StatelessWidget {
  const CircleAction({
    super.key,
    required this.glyph,
    required this.onTap,
    required this.semanticLabel,
    this.foreground,
    this.background,
    this.size = 48,
  });

  final NocturneGlyph glyph;
  final VoidCallback? onTap;
  final String semanticLabel;
  final Color? foreground;
  final Color? background;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    return Opacity(
      opacity: onTap == null ? 0.45 : 1,
      child: Pressable(
        onTap: onTap,
        semanticLabel: semanticLabel,
        scale: 0.92,
        child: SizedBox.square(
          dimension: NocturneSpace.minTap,
          child: Center(
            child: SizedBox.square(
              dimension: size.clamp(34, NocturneSpace.minTap),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: background ?? theme.glassStrong,
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.line, width: 1),
                ),
                child: Center(
                  child: NocturneIcon(
                    glyph,
                    size: size.clamp(34, NocturneSpace.minTap) * 0.42,
                    color: foreground ?? theme.ink,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
