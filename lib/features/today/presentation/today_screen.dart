import 'package:ayyam/core/settings/app_preferences.dart';
import 'package:ayyam/design/components/glass_card.dart';
import 'package:ayyam/design/components/nocturne_icon.dart';
import 'package:ayyam/design/components/nocturne_scaffold.dart';
import 'package:ayyam/design/theme/nocturne_theme.dart';
import 'package:ayyam/design/tokens/nocturne_tokens.dart';
import 'package:ayyam/design/type/nocturne_type.dart';
import 'package:flutter/widgets.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key, required this.preferences});

  final AppPreferences preferences;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    return NocturneScaffold(
      tone: NocturneTone.rest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          NocturneSpace.gutter,
          NocturneSpace.x3,
          NocturneSpace.gutter,
          NocturneSpace.x5,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text('AYYAM', style: NocturneType.label(theme.ink)),
                Text('TODAY / 001', style: NocturneType.label(theme.muted)),
              ],
            ),
            const SizedBox(height: NocturneSpace.x14),
            Text(
              'The first day\nis ready.',
              style: NocturneType.hero(theme.ink),
            ),
            const SizedBox(height: NocturneSpace.x5),
            Text(
              'Your setup is saved on this device. Daily content comes next.',
              style: NocturneType.body(theme.muted),
            ),
            const SizedBox(height: NocturneSpace.x8),
            GlassCard(
              glow: true,
              child: Column(
                children: <Widget>[
                  if (preferences.duaEnabled)
                    const _ReadyRow(
                      glyph: NocturneGlyph.book,
                      title: 'Dua Bucket List',
                      value: 'READY',
                    ),
                  if (preferences.duaEnabled && preferences.lifeInDotsEnabled)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: NocturneSpace.x4,
                      ),
                      child: ColoredBox(
                        color: theme.line,
                        child: const SizedBox(height: 1),
                      ),
                    ),
                  if (preferences.lifeInDotsEnabled)
                    const _ReadyRow(
                      glyph: NocturneGlyph.dots,
                      title: 'Life in Dots',
                      value: 'READY',
                    ),
                ],
              ),
            ),
            const Spacer(),
            Text(
              'FOUNDATION BUILD / LOCAL FIRST',
              style: NocturneType.label(theme.faint),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadyRow extends StatelessWidget {
  const _ReadyRow({
    required this.glyph,
    required this.title,
    required this.value,
  });

  final NocturneGlyph glyph;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    return Row(
      children: <Widget>[
        NocturneIcon(glyph, color: theme.ink),
        const SizedBox(width: NocturneSpace.x4),
        Expanded(child: Text(title, style: NocturneType.bodyStrong(theme.ink))),
        Text(value, style: NocturneType.label(theme.kept)),
      ],
    );
  }
}
