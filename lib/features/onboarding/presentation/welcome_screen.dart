import 'package:ayyam/design/components/glass_card.dart';
import 'package:ayyam/design/components/nocturne_button.dart';
import 'package:ayyam/design/components/nocturne_icon.dart';
import 'package:ayyam/design/components/nocturne_scaffold.dart';
import 'package:ayyam/design/theme/nocturne_theme.dart';
import 'package:ayyam/design/tokens/nocturne_tokens.dart';
import 'package:ayyam/design/type/nocturne_type.dart';
import 'package:flutter/widgets.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.onBegin});

  final VoidCallback onBegin;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);

    return NocturneScaffold(
      tone: NocturneTone.pending,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          NocturneSpace.gutter,
          NocturneSpace.x3,
          NocturneSpace.gutter,
          NocturneSpace.x5,
        ),
        child: Column(
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text('AYYAM', style: NocturneType.label(theme.ink)),
                Text('WELCOME / 001', style: NocturneType.label(theme.muted)),
              ],
            ),
            const SizedBox(height: NocturneSpace.x6),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const SizedBox(height: NocturneSpace.x8),
                    Text(
                      'Make each\nday count.',
                      style: NocturneType.hero(theme.ink, size: 52),
                    ),
                    const SizedBox(height: NocturneSpace.x5),
                    Text(
                      'One new dua. One honest view of the days you have lived.',
                      style: NocturneType.body(theme.muted),
                    ),
                    const SizedBox(height: NocturneSpace.x8),
                    GlassCard(
                      glow: true,
                      child: Column(
                        children: <Widget>[
                          _PromiseRow(
                            glyph: NocturneGlyph.book,
                            title: 'A dua for today',
                            body: 'Sourced, saved, and never repeated.',
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: NocturneSpace.x4,
                            ),
                            child: ColoredBox(
                              color: theme.line,
                              child: const SizedBox(height: 1),
                            ),
                          ),
                          _PromiseRow(
                            glyph: NocturneGlyph.dots,
                            title: 'A life in days',
                            body: 'Private prayer reflection, held on device.',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: NocturneSpace.x4),
            NocturneButton(
              label: 'Begin',
              trailing: NocturneGlyph.arrowRight,
              onTap: onBegin,
            ),
            const SizedBox(height: NocturneSpace.x3),
            Text(
              'Private by default. No account required.',
              textAlign: TextAlign.center,
              style: NocturneType.caption(theme.faint),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromiseRow extends StatelessWidget {
  const _PromiseRow({
    required this.glyph,
    required this.title,
    required this.body,
  });

  final NocturneGlyph glyph;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox.square(
          dimension: NocturneSpace.minTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme.glass,
              borderRadius: BorderRadius.circular(NocturneRadius.small),
              border: Border.all(color: theme.line),
            ),
            child: Center(
              child: NocturneIcon(glyph, color: theme.ink, size: 21),
            ),
          ),
        ),
        const SizedBox(width: NocturneSpace.x4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: NocturneType.cardTitle(theme.ink)),
              const SizedBox(height: NocturneSpace.x1),
              Text(body, style: NocturneType.caption(theme.muted)),
            ],
          ),
        ),
      ],
    );
  }
}
