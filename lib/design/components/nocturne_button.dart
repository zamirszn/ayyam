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
      NocturneButtonStyle.signal => (theme.accent, theme.canvas, theme.accent),
      NocturneButtonStyle.ink => (theme.ink, theme.canvas, theme.ink),
      NocturneButtonStyle.glass => (theme.glass, theme.ink, theme.lineStrong),
      NocturneButtonStyle.danger => (theme.missed, theme.canvas, theme.missed),
    };

    final button = SizedBox(
      height: compact ? 44 : 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(NocturneRadius.pill),
          border: Border.all(color: border),
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
        child: expand
            ? SizedBox(width: double.infinity, child: button)
            : button,
      ),
    );
  }
}
