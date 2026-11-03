import 'dart:ui' show ImageFilter;

import 'package:ayyam/design/components/nocturne_icon.dart';
import 'package:ayyam/design/components/pressable.dart';
import 'package:ayyam/design/theme/nocturne_theme.dart';
import 'package:ayyam/design/tokens/nocturne_tokens.dart';
import 'package:ayyam/design/type/nocturne_type.dart';
import 'package:flutter/widgets.dart';

class NocturneNavItem {
  const NocturneNavItem({
    required this.label,
    required this.glyph,
    required this.onTap,
    this.semanticLabel,
  });

  final String label;
  final NocturneGlyph glyph;
  final VoidCallback onTap;
  final String? semanticLabel;
}

class NocturneNavShell extends StatelessWidget {
  const NocturneNavShell({
    super.key,
    required this.selectedIndex,
    required this.items,
  });

  final int selectedIndex;
  final List<NocturneNavItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.canvas.withValues(alpha: 0.78),
            border: Border(top: BorderSide(color: theme.line)),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: NocturneSpace.navHeight,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final slot = constraints.maxWidth / items.length;
                  const indicatorWidth = 76.0;
                  const indicatorHeight = 48.0;
                  final center = (selectedIndex + 0.5) * slot;
                  final left = (center - indicatorWidth / 2).clamp(
                    0.0,
                    constraints.maxWidth - indicatorWidth,
                  );
                  return Stack(
                    children: <Widget>[
                      AnimatedPositioned(
                        duration: NocturneDuration.base,
                        curve: Curves.easeOutCubic,
                        left: left,
                        top: (NocturneSpace.navHeight - indicatorHeight) / 2,
                        width: indicatorWidth,
                        height: indicatorHeight,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: theme.glassStrong,
                              borderRadius: BorderRadius.circular(
                                NocturneRadius.pill,
                              ),
                              border: Border.all(color: theme.line),
                            ),
                          ),
                        ),
                      ),
                      Row(
                        children: <Widget>[
                          for (var index = 0; index < items.length; index++)
                            Expanded(
                              child: _NavButton(
                                item: items[index],
                                selected: index == selectedIndex,
                              ),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.item, required this.selected});

  final NocturneNavItem item;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    final color = selected ? theme.ink : theme.faint;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: item.semanticLabel ?? item.label,
      onTap: item.onTap,
      child: ExcludeSemantics(
        child: Pressable(
          onTap: item.onTap,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                NocturneIcon(item.glyph, size: 21, color: color),
                const SizedBox(height: 4),
                Text(
                  item.label,
                  style: NocturneType.label(color)
                      .copyWith(fontSize: 9, letterSpacing: 0.8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
