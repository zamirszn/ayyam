import 'package:ayyam/core/settings/app_preferences.dart';
import 'package:ayyam/design/components/glass_card.dart';
import 'package:ayyam/design/components/nocturne_button.dart';
import 'package:ayyam/design/components/nocturne_icon.dart';
import 'package:ayyam/design/components/nocturne_scaffold.dart';
import 'package:ayyam/design/components/pressable.dart';
import 'package:ayyam/design/routes/nocturne_page_route.dart';
import 'package:ayyam/design/theme/nocturne_theme.dart';
import 'package:ayyam/design/tokens/nocturne_tokens.dart';
import 'package:ayyam/design/type/nocturne_type.dart';
import 'package:ayyam/features/dua/application/today_dua_controller.dart';
import 'package:ayyam/features/dua/domain/dua.dart';
import 'package:ayyam/features/settings/presentation/settings_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key, required this.preferences});

  final AppPreferences preferences;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(currentDateProvider);
    final duaState = preferences.duaEnabled
        ? ref.watch(todayDuaProvider)
        : null;
    final readyState = duaState?.value;
    final tone = readyState is TodayDuaReady && readyState.dua.isRecited
        ? NocturneTone.kept
        : NocturneTone.rest;
    final theme = NocturneScope.of(context);

    return NocturneScaffold(
      tone: tone,
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
                Text('AYYAM', style: NocturneType.label(theme.ink)),
                const Spacer(),
                Text('TODAY / 001', style: NocturneType.label(theme.muted)),
                const SizedBox(width: NocturneSpace.x3),
                CircleAction(
                  glyph: NocturneGlyph.settings,
                  onTap: () => _openSettings(context),
                  semanticLabel: 'Open settings',
                  size: 38,
                ),
              ],
            ),
            const SizedBox(height: NocturneSpace.x6),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _dateLabel(today),
                      style: NocturneType.label(theme.faint),
                    ),
                    const SizedBox(height: NocturneSpace.x3),
                    if (duaState != null)
                      duaState.when(
                        data: (state) => _DuaStateView(
                          state: state,
                          onRetry: () =>
                              ref.read(todayDuaProvider.notifier).retry(),
                          onOpenSettings: () => _openSettings(context),
                          onMarkRecited: () =>
                              ref.read(todayDuaProvider.notifier).markRecited(),
                          onReportIssue: () =>
                              ref.read(todayDuaProvider.notifier).reportIssue(),
                        ),
                        error: (error, stackTrace) => _UnavailableDua(
                          message: 'Local storage could not be opened. Your settings and key were not changed.',
                          onRetry: () =>
                              ref.read(todayDuaProvider.notifier).retry(),
                        ),
                        loading: _LoadingDua.new,
                      )
                    else
                      const _LifeOnlyHeader(),
                    if (preferences.lifeInDotsEnabled) ...<Widget>[
                      const SizedBox(height: NocturneSpace.x8),
                      const _LifePreview(),
                    ],
                    const SizedBox(height: NocturneSpace.x8),
                    Text(
                      'LOCAL FIRST / PRIVATE BY DEFAULT',
                      style: NocturneType.label(theme.faint),
                    ),
                    const SizedBox(height: NocturneSpace.x3),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openSettings(BuildContext context) {
    Navigator.of(context).push<void>(
      nocturnePageRoute<void>(
        const RouteSettings(name: '/settings'),
        (_) => SettingsScreen(initialPreferences: preferences),
      ),
    );
  }

  static String _dateLabel(DateTime date) {
    const months = <String>[
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return '${date.day.toString().padLeft(2, '0')} '
        '${months[date.month - 1]} ${date.year}';
  }
}

class _DuaStateView extends StatelessWidget {
  const _DuaStateView({
    required this.state,
    required this.onRetry,
    required this.onOpenSettings,
    required this.onMarkRecited,
    required this.onReportIssue,
  });

  final TodayDuaState state;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;
  final VoidCallback onMarkRecited;
  final VoidCallback onReportIssue;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      TodayDuaDisabled() => const SizedBox.shrink(),
      TodayDuaNeedsKey(:final rejected) => _NeedsKeyDua(
        rejected: rejected,
        onOpenSettings: onOpenSettings,
      ),
      TodayDuaReady(:final dua) => _ReadyDua(
        dua: dua,
        onMarkRecited: onMarkRecited,
        onReportIssue: onReportIssue,
      ),
      TodayDuaFlagged() => const _FlaggedDua(),
      TodayDuaUnavailable(:final message, :final canRetry) => _UnavailableDua(
        message: message,
        onRetry: canRetry ? onRetry : null,
      ),
    };
  }
}

class _LoadingDua extends StatelessWidget {
  const _LoadingDua();

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Preparing the\nday.', style: NocturneType.hero(theme.ink)),
        const SizedBox(height: NocturneSpace.x4),
        Text(
          'Checking local history, source requirements and today’s language.',
          style: NocturneType.body(theme.muted),
        ),
        const SizedBox(height: NocturneSpace.x6),
        GlassCard(
          glow: true,
          tint: theme.pending,
          child: Row(
            children: <Widget>[
              NocturneIcon(NocturneGlyph.book, color: theme.pending),
              const SizedBox(width: NocturneSpace.x4),
              Expanded(
                child: Text(
                  'PREPARING A SOURCED DUA',
                  style: NocturneType.label(theme.muted),
                ),
              ),
              Text('•••', style: NocturneType.mono(theme.faint)),
            ],
          ),
        ),
      ],
    );
  }
}

class _NeedsKeyDua extends StatelessWidget {
  const _NeedsKeyDua({required this.rejected, required this.onOpenSettings});

  final bool rejected;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('The key is\nmissing.', style: NocturneType.hero(theme.ink)),
        const SizedBox(height: NocturneSpace.x4),
        Text(
          rejected
              ? 'Gemini no longer accepts the saved key. Replace or remove it in Settings.'
              : 'Add a Gemini API key to prepare a new sourced dua. Nothing is sent through an Ayyam server.',
          style: NocturneType.body(theme.muted),
        ),
        const SizedBox(height: NocturneSpace.x6),
        NocturneButton(
          label: 'Open settings',
          trailing: NocturneGlyph.arrowRight,
          onTap: onOpenSettings,
        ),
      ],
    );
  }
}

class _UnavailableDua extends StatelessWidget {
  const _UnavailableDua({required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('The day is\nwaiting.', style: NocturneType.hero(theme.ink)),
        const SizedBox(height: NocturneSpace.x4),
        Text(message, style: NocturneType.body(theme.muted)),
        if (onRetry != null) ...<Widget>[
          const SizedBox(height: NocturneSpace.x6),
          NocturneButton(
            label: 'Try again',
            style: NocturneButtonStyle.glass,
            trailing: NocturneGlyph.arrowRight,
            onTap: onRetry,
          ),
        ],
      ],
    );
  }
}

class _ReadyDua extends StatelessWidget {
  const _ReadyDua({
    required this.dua,
    required this.onMarkRecited,
    required this.onReportIssue,
  });

  final Dua dua;
  final VoidCallback onMarkRecited;
  final VoidCallback onReportIssue;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text('TODAY’S DUA', style: NocturneType.label(theme.accent)),
            const Spacer(),
            Text(
              dua.isRecited ? 'RECITED' : 'READY',
              style: NocturneType.label(
                dua.isRecited ? theme.kept : theme.pending,
              ),
            ),
          ],
        ),
        const SizedBox(height: NocturneSpace.x3),
        Text(
          dua.isRecited ? 'Held for\ntoday.' : 'A prayer for\ntoday.',
          style: NocturneType.hero(theme.ink),
        ),
        const SizedBox(height: NocturneSpace.x6),
        GlassCard(
          glow: true,
          tint: dua.isRecited ? theme.kept : theme.pending,
          padding: const EdgeInsets.all(NocturneSpace.x6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (dua.occasion case final occasion?) ...<Widget>[
                Text(
                  occasion.toUpperCase(),
                  style: NocturneType.label(theme.pending),
                ),
                const SizedBox(height: NocturneSpace.x4),
              ],
              Directionality(
                textDirection: TextDirection.rtl,
                child: SizedBox(
                  width: double.infinity,
                  child: Text(
                    dua.arabic,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: theme.ink,
                      fontSize: 31,
                      height: 1.75,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: NocturneSpace.x5),
              Text(
                dua.transliteration,
                style: NocturneType.body(theme.muted)
                    .copyWith(fontStyle: FontStyle.italic, height: 1.55),
              ),
              const SizedBox(height: NocturneSpace.x5),
              ColoredBox(
                color: theme.line,
                child: const SizedBox(width: double.infinity, height: 1),
              ),
              const SizedBox(height: NocturneSpace.x5),
              Text(
                dua.translation,
                style: NocturneType.title(theme.ink).copyWith(height: 1.25),
              ),
            ],
          ),
        ),
        const SizedBox(height: NocturneSpace.x5),
        const _SectionRule(index: '01', label: 'Context'),
        const SizedBox(height: NocturneSpace.x3),
        Text(dua.benefits, style: NocturneType.body(theme.muted)),
        const SizedBox(height: NocturneSpace.x6),
        const _SectionRule(index: '02', label: 'Sources'),
        const SizedBox(height: NocturneSpace.x3),
        for (var index = 0; index < dua.sources.length; index++) ...<Widget>[
          _SourceRow(source: dua.sources[index]),
          if (index != dua.sources.length - 1)
            const SizedBox(height: NocturneSpace.x2),
        ],
        const SizedBox(height: NocturneSpace.x5),
        GlassCard(
          radius: NocturneRadius.medium,
          tint: theme.muted,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              NocturneIcon(NocturneGlyph.lock, color: theme.muted),
              const SizedBox(width: NocturneSpace.x3),
              Expanded(
                child: Text(
                  'Generated with AI from the cited source. Verify the wording and attribution with a trusted source or qualified scholar.',
                  style: NocturneType.caption(theme.muted),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: NocturneSpace.x5),
        NocturneButton(
          label: dua.isRecited ? 'Recited today' : 'Mark as recited',
          style: dua.isRecited
              ? NocturneButtonStyle.glass
              : NocturneButtonStyle.signal,
          trailing: NocturneGlyph.check,
          onTap: dua.isRecited ? null : onMarkRecited,
        ),
        const SizedBox(height: NocturneSpace.x2),
        Align(
          alignment: Alignment.center,
          child: Pressable(
            onTap: onReportIssue,
            semanticLabel: 'Report an issue with this dua',
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: NocturneSpace.x4,
                vertical: NocturneSpace.x3,
              ),
              child: Text(
                'REPORT AN ISSUE',
                style: NocturneType.label(theme.missed),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FlaggedDua extends StatelessWidget {
  const _FlaggedDua();

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Hidden for\nreview.', style: NocturneType.hero(theme.ink)),
        const SizedBox(height: NocturneSpace.x4),
        Text(
          'This dua was flagged locally and will remain excluded from future daily generation.',
          style: NocturneType.body(theme.muted),
        ),
        const SizedBox(height: NocturneSpace.x6),
        GlassCard(
          tint: theme.missed,
          child: Row(
            children: <Widget>[
              NocturneIcon(NocturneGlyph.lock, color: theme.missed),
              const SizedBox(width: NocturneSpace.x3),
              Expanded(
                child: Text(
                  'The report stays on this device. No content was sent to Ayyam.',
                  style: NocturneType.caption(theme.muted),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.source});

  final DuaSource source;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    return GlassCard(
      radius: NocturneRadius.medium,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.kept.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(NocturneRadius.small),
              border: Border.all(color: theme.kept.withValues(alpha: 0.26)),
            ),
            child: NocturneIcon(
              NocturneGlyph.check,
              size: 18,
              color: theme.kept,
            ),
          ),
          const SizedBox(width: NocturneSpace.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  source.collection,
                  style: NocturneType.bodyStrong(theme.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  source.reference,
                  style: NocturneType.caption(theme.muted),
                ),
              ],
            ),
          ),
          if (source.grading case final grading?)
            Text(grading.toUpperCase(), style: NocturneType.label(theme.kept)),
        ],
      ),
    );
  }
}

class _LifeOnlyHeader extends StatelessWidget {
  const _LifeOnlyHeader();

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('A life in\ndays.', style: NocturneType.hero(theme.ink)),
        const SizedBox(height: NocturneSpace.x4),
        Text(
          'Your private prayer reflection is ready for its first daily check-in.',
          style: NocturneType.body(theme.muted),
        ),
      ],
    );
  }
}

class _LifePreview extends StatelessWidget {
  const _LifePreview();

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _SectionRule(index: 'L1', label: 'Life in Dots'),
        const SizedBox(height: NocturneSpace.x3),
        GlassCard(
          child: Row(
            children: <Widget>[
              NocturneIcon(NocturneGlyph.dots, color: theme.ink),
              const SizedBox(width: NocturneSpace.x4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Lifetime view ready',
                      style: NocturneType.bodyStrong(theme.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Daily prayer check-ins arrive in the Life in Dots milestone.',
                      style: NocturneType.caption(theme.muted),
                    ),
                  ],
                ),
              ),
              Text('NEXT', style: NocturneType.label(theme.faint)),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionRule extends StatelessWidget {
  const _SectionRule({required this.index, required this.label});

  final String index;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    return Row(
      children: <Widget>[
        Text(index, style: NocturneType.label(theme.accent)),
        const SizedBox(width: NocturneSpace.x3),
        Expanded(
          child: ColoredBox(
            color: theme.line,
            child: const SizedBox(height: 1),
          ),
        ),
        const SizedBox(width: NocturneSpace.x3),
        Text(label.toUpperCase(), style: NocturneType.label(theme.muted)),
      ],
    );
  }
}
