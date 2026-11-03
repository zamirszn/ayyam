import 'package:ayyam/design/components/glass_card.dart';
import 'package:ayyam/design/components/nocturne_button.dart';
import 'package:ayyam/design/components/nocturne_icon.dart';
import 'package:ayyam/design/components/nocturne_scaffold.dart';
import 'package:ayyam/design/routes/nocturne_page_route.dart';
import 'package:ayyam/design/theme/nocturne_theme.dart';
import 'package:ayyam/design/tokens/nocturne_tokens.dart';
import 'package:ayyam/design/type/nocturne_type.dart';
import 'package:ayyam/features/life/application/life_dashboard_controller.dart';
import 'package:ayyam/features/life/domain/prayer_day.dart';
import 'package:ayyam/features/life/presentation/life_backfill_screen.dart';
import 'package:ayyam/features/life/presentation/life_analytics_screen.dart';
import 'package:ayyam/features/life/presentation/life_dots_view.dart';
import 'package:ayyam/features/life/presentation/makeup_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LifeScreen extends ConsumerStatefulWidget {
  const LifeScreen({super.key});

  @override
  ConsumerState<LifeScreen> createState() => _LifeScreenState();
}

class _LifeScreenState extends ConsumerState<LifeScreen> {
  LifeDot? _selectedDot;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    final dashboard = ref.watch(lifeDashboardProvider);
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
                Text('LIFE / 005', style: NocturneType.label(theme.muted)),
              ],
            ),
            const SizedBox(height: NocturneSpace.x5),
            Expanded(
              child: dashboard.when(
                data: _buildDashboard,
                error: (error, stackTrace) => _LifeError(
                  message: error is LifeSetupException
                      ? error.message
                      : 'Life in Dots could not read local records.',
                  onRetry: () => ref.invalidate(lifeDashboardProvider),
                ),
                loading: () => const _LifeLoading(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard(LifeDashboard value) {
    final theme = NocturneScope.of(context);
    final selected = _selectedDot ?? value.dotFor(value.today);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'A life in\ndays.',
            style: NocturneType.hero(theme.ink, size: 50),
          ),
          const SizedBox(height: NocturneSpace.x4),
          Text(
            'A private 100-year view. Recorded prayer days use color; unrecorded days stay neutral.',
            style: NocturneType.body(theme.muted),
          ),
          const SizedBox(height: NocturneSpace.x6),
          _LifeCounters(summary: value.summary),
          const SizedBox(height: NocturneSpace.x6),
          GlassCard(
            padding: const EdgeInsets.all(NocturneSpace.x3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        '36,500+ DAYS',
                        style: NocturneType.label(theme.muted),
                      ),
                    ),
                    Text(
                      'SCROLL · TAP',
                      style: NocturneType.label(theme.faint),
                    ),
                  ],
                ),
                const SizedBox(height: NocturneSpace.x3),
                LifeDotsView(
                  years: value.years,
                  selectedDate: selected?.date,
                  onSelected: (dot) => setState(() => _selectedDot = dot),
                ),
                const SizedBox(height: NocturneSpace.x3),
                const _DotLegend(),
              ],
            ),
          ),
          if (selected != null) ...<Widget>[
            const SizedBox(height: NocturneSpace.x3),
            _SelectedDayCard(dot: selected),
          ],
          const SizedBox(height: NocturneSpace.x8),
          _TodayCheckIn(dashboard: value),
          const SizedBox(height: NocturneSpace.x8),
          Text('PERSONAL MAKE-UP', style: NocturneType.label(theme.muted)),
          const SizedBox(height: NocturneSpace.x3),
          GlassCard(
            onTap: _openAnalytics,
            semanticLabel: 'Open Life analytics',
            child: Row(
              children: <Widget>[
                NocturneIcon(NocturneGlyph.dots, color: theme.kept),
                const SizedBox(width: NocturneSpace.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'View prayer patterns',
                        style: NocturneType.bodyStrong(theme.ink),
                      ),
                      Text(
                        'Completion rates, monthly totals, and projection.',
                        style: NocturneType.caption(theme.muted),
                      ),
                    ],
                  ),
                ),
                NocturneIcon(
                  NocturneGlyph.arrowRight,
                  size: 18,
                  color: theme.faint,
                ),
              ],
            ),
          ),
          const SizedBox(height: NocturneSpace.x3),
          GlassCard(
            onTap: _openMakeup,
            semanticLabel: 'Open personal make-up tracking',
            tint: theme.blue,
            child: Row(
              children: <Widget>[
                NocturneIcon(NocturneGlyph.check, color: theme.blue),
                const SizedBox(width: NocturneSpace.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        '${value.summary.outstandingDebts} outstanding',
                        style: NocturneType.bodyStrong(theme.ink),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${value.summary.estimatedOutstandingDebts} from your undated estimate',
                        style: NocturneType.caption(theme.muted),
                      ),
                    ],
                  ),
                ),
                NocturneIcon(
                  NocturneGlyph.arrowRight,
                  size: 18,
                  color: theme.faint,
                ),
              ],
            ),
          ),
          const SizedBox(height: NocturneSpace.x3),
          GlassCard(
            onTap: () => _openBackfill(value),
            semanticLabel: 'Backfill a past prayer range',
            child: Row(
              children: <Widget>[
                NocturneIcon(NocturneGlyph.calendar, color: theme.muted),
                const SizedBox(width: NocturneSpace.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Backfill a past range',
                        style: NocturneType.bodyStrong(theme.ink),
                      ),
                      Text(
                        'Store an explicit completed or missed estimate.',
                        style: NocturneType.caption(theme.muted),
                      ),
                    ],
                  ),
                ),
                NocturneIcon(
                  NocturneGlyph.arrowRight,
                  size: 18,
                  color: theme.faint,
                ),
              ],
            ),
          ),
          const SizedBox(height: NocturneSpace.x5),
          GlassCard(
            tint: theme.missed,
            child: Text(
              'This is a personal reflection tool, not a ruling. Prayer make-up views differ; consult a qualified scholar for guidance.',
              style: NocturneType.caption(theme.muted),
            ),
          ),
          const SizedBox(height: NocturneSpace.x5),
        ],
      ),
    );
  }

  void _openMakeup() {
    Navigator.of(context).push<void>(
      nocturnePageRoute<void>(
        const RouteSettings(name: '/life/makeup'),
        (_) => const MakeupScreen(),
      ),
    );
  }

  void _openBackfill(LifeDashboard dashboard) {
    Navigator.of(context).push<void>(
      nocturnePageRoute<void>(
        const RouteSettings(name: '/life/backfill'),
        (_) => LifeBackfillScreen(
          dateOfBirth: dashboard.dateOfBirth,
          today: dashboard.today,
        ),
      ),
    );
  }

  void _openAnalytics() {
    Navigator.of(context).push<void>(
      nocturnePageRoute<void>(
        const RouteSettings(name: '/life/analytics'),
        (_) => const LifeAnalyticsScreen(),
      ),
    );
  }
}

class _LifeCounters extends StatelessWidget {
  const _LifeCounters({required this.summary});

  final LifeSummary summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _CounterCard(value: '${summary.daysLived}', label: 'LIVED'),
        ),
        const SizedBox(width: NocturneSpace.x2),
        Expanded(
          child: _CounterCard(
            value: '${summary.daysRemaining}',
            label: 'REMAINING',
          ),
        ),
        const SizedBox(width: NocturneSpace.x2),
        Expanded(
          child: _CounterCard(
            value: '${(summary.percentLived * 100).toStringAsFixed(1)}%',
            label: 'LIVED',
          ),
        ),
      ],
    );
  }
}

class _CounterCard extends StatelessWidget {
  const _CounterCard({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    return GlassCard(
      radius: NocturneRadius.medium,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
      child: Column(
        children: <Widget>[
          FittedBox(child: Text(value, style: NocturneType.title(theme.ink))),
          Text(label, style: NocturneType.label(theme.faint)),
        ],
      ),
    );
  }
}

class _TodayCheckIn extends ConsumerWidget {
  const _TodayCheckIn({required this.dashboard});

  final LifeDashboard dashboard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = NocturneScope.of(context);
    final entry = dashboard.todayEntry;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text('TODAY’S CHECK-IN', style: NocturneType.label(theme.muted)),
            const Spacer(),
            if (entry != null)
              Text(
                entry.status == PrayerDayStatus.completed
                    ? 'ALL 5 PRAYED'
                    : 'MISSED',
                style: NocturneType.label(
                  entry.status == PrayerDayStatus.completed
                      ? theme.kept
                      : theme.missed,
                ),
              ),
          ],
        ),
        const SizedBox(height: NocturneSpace.x3),
        GlassCard(
          tint: entry?.status == PrayerDayStatus.completed
              ? theme.kept
              : entry?.status == PrayerDayStatus.missed
              ? theme.missed
              : theme.pending,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                entry == null
                    ? 'How was today’s prayer day?'
                    : 'You can correct today’s check-in at any time.',
                style: NocturneType.bodyStrong(theme.ink),
              ),
              const SizedBox(height: NocturneSpace.x4),
              NocturneButton(
                label: 'All 5 prayed',
                trailing: NocturneGlyph.check,
                onTap: () {
                  ref
                      .read(lifeDashboardProvider.notifier)
                      .recordToday(PrayerDayStatus.completed);
                },
              ),
              const SizedBox(height: NocturneSpace.x2),
              NocturneButton(
                label: 'One or more missed',
                style: NocturneButtonStyle.danger,
                onTap: () {
                  ref
                      .read(lifeDashboardProvider.notifier)
                      .recordToday(PrayerDayStatus.missed);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DotLegend extends StatelessWidget {
  const _DotLegend();

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    return Wrap(
      spacing: NocturneSpace.x3,
      runSpacing: NocturneSpace.x2,
      children: <Widget>[
        _LegendItem(label: 'Completed', color: theme.kept),
        _LegendItem(label: 'Missed', color: theme.missed),
        _LegendItem(label: 'Repaid', color: theme.blue),
        _LegendItem(label: 'Unrecorded', color: theme.faint),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: NocturneSpace.x1),
        Text(label, style: NocturneType.caption(theme.muted)),
      ],
    );
  }
}

class _SelectedDayCard extends StatelessWidget {
  const _SelectedDayCard({required this.dot});

  final LifeDot dot;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    final color = switch (dot.state) {
      LifeDotState.completed => theme.kept,
      LifeDotState.missed => theme.missed,
      LifeDotState.repaid => theme.blue,
      LifeDotState.unrecorded || LifeDotState.remaining => theme.faint,
    };
    return GlassCard(
      radius: NocturneRadius.medium,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      tint: color,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _dateLabel(dot.date),
                  style: NocturneType.bodyStrong(theme.ink),
                ),
                Text(
                  dot.estimated ? 'ESTIMATED ENTRY' : _dotLabel(dot),
                  style: NocturneType.label(color),
                ),
              ],
            ),
          ),
          if (dot.isToday)
            Text('TODAY', style: NocturneType.label(theme.accent)),
        ],
      ),
    );
  }
}

class _LifeLoading extends StatelessWidget {
  const _LifeLoading();

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    return Center(
      child: Text(
        'PLACING 36,500+ DOTS…',
        style: NocturneType.label(theme.muted),
      ),
    );
  }
}

class _LifeError extends StatelessWidget {
  const _LifeError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    return Center(
      child: GlassCard(
        onTap: onRetry,
        semanticLabel: 'Retry Life in Dots',
        child: Text(message, style: NocturneType.body(theme.muted)),
      ),
    );
  }
}

String _dotLabel(LifeDot dot) {
  return switch (dot.state) {
    LifeDotState.unrecorded => 'UNRECORDED',
    LifeDotState.completed => 'ALL 5 PRAYED',
    LifeDotState.missed => 'MISSED',
    LifeDotState.repaid => 'REPAID',
    LifeDotState.remaining => 'FUTURE DAY',
  };
}

String _dateLabel(DateTime value) {
  return '${value.day.toString().padLeft(2, '0')} / '
      '${value.month.toString().padLeft(2, '0')} / ${value.year}';
}
