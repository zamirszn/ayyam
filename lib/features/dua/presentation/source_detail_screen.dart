import 'package:ayyam/design/components/glass_card.dart';
import 'package:ayyam/design/components/nocturne_button.dart';
import 'package:ayyam/design/components/nocturne_icon.dart';
import 'package:ayyam/design/components/nocturne_scaffold.dart';
import 'package:ayyam/design/theme/nocturne_theme.dart';
import 'package:ayyam/design/tokens/nocturne_tokens.dart';
import 'package:ayyam/design/type/nocturne_type.dart';
import 'package:ayyam/features/dua/domain/dua.dart';
import 'package:flutter/widgets.dart';

class SourceDetailScreen extends StatelessWidget {
  const SourceDetailScreen({
    super.key,
    required this.source,
    required this.dua,
  });

  final DuaSource source;
  final Dua dua;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    return NocturneScaffold(
      tone: NocturneTone.rest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          NocturneSpace.gutter,
          NocturneSpace.x2,
          NocturneSpace.gutter,
          NocturneSpace.x5,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                CircleAction(
                  glyph: NocturneGlyph.chevronLeft,
                  onTap: () => Navigator.of(context).maybePop(),
                  semanticLabel: 'Back',
                  size: 38,
                ),
                const Spacer(),
                Text('SOURCE / 004', style: NocturneType.label(theme.muted)),
              ],
            ),
            const SizedBox(height: NocturneSpace.x6),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Follow the\nreference.',
                      style: NocturneType.hero(theme.ink, size: 50),
                    ),
                    const SizedBox(height: NocturneSpace.x4),
                    Text(
                      'Ayyam keeps the model’s citation visible so the wording and attribution can be checked independently.',
                      style: NocturneType.body(theme.muted),
                    ),
                    const SizedBox(height: NocturneSpace.x8),
                    _ReferenceField(
                      label: 'Source type',
                      value: source.type == DuaSourceType.quran
                          ? 'Quran'
                          : 'Hadith',
                    ),
                    const SizedBox(height: NocturneSpace.x3),
                    _ReferenceField(
                      label: 'Collection',
                      value: source.collection,
                    ),
                    const SizedBox(height: NocturneSpace.x3),
                    _ReferenceField(
                      label: 'Reference',
                      value: source.reference,
                    ),
                    const SizedBox(height: NocturneSpace.x3),
                    _ReferenceField(
                      label: 'Grading',
                      value: source.grading ?? 'Not supplied',
                    ),
                    const SizedBox(height: NocturneSpace.x8),
                    Text(
                      'CITED WORDING',
                      style: NocturneType.label(theme.muted),
                    ),
                    const SizedBox(height: NocturneSpace.x3),
                    GlassCard(
                      tint: theme.pending,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Directionality(
                            textDirection: TextDirection.rtl,
                            child: SizedBox(
                              width: double.infinity,
                              child: Text(
                                dua.arabic,
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  color: theme.ink,
                                  fontSize: 26,
                                  height: 1.7,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: NocturneSpace.x4),
                          Text(
                            dua.translation,
                            style: NocturneType.body(theme.muted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: NocturneSpace.x5),
                    GlassCard(
                      tint: theme.missed,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          NocturneIcon(NocturneGlyph.lock, color: theme.missed),
                          const SizedBox(width: NocturneSpace.x3),
                          Expanded(
                            child: Text(
                              'AI can misquote or misattribute a source. Verify this reference in a trusted Quran or hadith edition, or with a qualified scholar.',
                              style: NocturneType.caption(theme.muted),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: NocturneSpace.x5),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReferenceField extends StatelessWidget {
  const _ReferenceField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    return GlassCard(
      radius: NocturneRadius.medium,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, style: NocturneType.body(theme.muted))),
          const SizedBox(width: NocturneSpace.x3),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: NocturneType.bodyStrong(theme.ink),
            ),
          ),
        ],
      ),
    );
  }
}
