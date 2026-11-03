import 'dart:math' as math;

import 'package:ayyam/design/components/glass_card.dart';
import 'package:ayyam/design/components/nocturne_button.dart';
import 'package:ayyam/design/components/nocturne_icon.dart';
import 'package:ayyam/design/components/nocturne_scaffold.dart';
import 'package:ayyam/design/theme/nocturne_theme.dart';
import 'package:ayyam/design/tokens/nocturne_tokens.dart';
import 'package:ayyam/design/type/nocturne_type.dart';
import 'package:ayyam/features/life/application/life_analytics_service.dart';
import 'package:ayyam/features/life/application/life_dashboard_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LifeAnalyticsScreen extends ConsumerWidget {
  const LifeAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                Text('ANALYTICS / 007', style: NocturneType.label(theme.muted)),
              ],
            ),
            const SizedBox(height: NocturneSpace.x6),
            Expanded(
              child: dashboard.when(
                data: (value) => _AnalyticsBody(
                  analytics: const LifeAnalyticsService().build(value),
                ),
                error: (error, stackTrace) => Center(
                  child: Text(
                    'Analytics could not read local records.',
                    style: NocturneType.body(theme.muted),
                  ),
                ),
                loading: () => Center(
                  child: Text(
                    'CALCULATING LOCALLY…',
                    style: NocturneType.label(theme.muted),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalyticsBody extends StatelessWidget {
  const _AnalyticsBody({required this.analytics});

  final LifeAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Patterns,\nnot pressure.',
            style: NocturneType.hero(theme.ink, size: 50),
          ),
          const SizedBox(height: NocturneSpace.x4),
          Text(
            'A private summary of the days you recorded. Unrecorded days are excluded from prayer completion rates.',
            style: NocturneType.body(theme.muted),
          ),
          const SizedBox(height: NocturneSpace.x8),
          Text('COMPLETION RATE', style: NocturneType.label(theme.muted)),
          const SizedBox(height: NocturneSpace.x3),
          Row(
            children: <Widget>[
              Expanded(
                child: _RateCard(label: '30 DAYS', rate: analytics.last30Days),
              ),
              const SizedBox(width: NocturneSpace.x2),
              Expanded(
                child: _RateCard(label: '1 YEAR', rate: analytics.lastYear),
              ),
              const SizedBox(width: NocturneSpace.x2),
              Expanded(
                child: _RateCard(label: 'LIFETIME', rate: analytics.lifetime),
              ),
            ],
          ),
          const SizedBox(height: NocturneSpace.x8),
          Text('SIX-MONTH VIEW', style: NocturneType.label(theme.muted)),
          const SizedBox(height: NocturneSpace.x3),
          GlassCard(
            padding: const EdgeInsets.fromLTRB(14, 20, 14, 14),
            child: Column(
              children: <Widget>[
                SizedBox(
                  height: 180,
                  child: _MonthlyChart(months: analytics.months),
                ),
                const SizedBox(height: NocturneSpace.x4),
                const _ChartLegend(),
              ],
            ),
          ),
          const SizedBox(height: NocturneSpace.x8),
          Text('PRAYER RECORD', style: NocturneType.label(theme.muted)),
          const SizedBox(height: NocturneSpace.x3),
          _YearsCard(analytics: analytics),
          const SizedBox(height: NocturneSpace.x3),
          _ProjectionCard(analytics: analytics),
          const SizedBox(height: NocturneSpace.x5),
        ],
      ),
    );
  }
}

class _RateCard extends StatelessWidget {
  const _RateCard({required this.label, required this.rate});

  final String label;
  final CompletionRate rate;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    final value = rate.value;
    return GlassCard(
      radius: NocturneRadius.medium,
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 14),
      child: Column(
        children: <Widget>[
          FittedBox(
            child: Text(
              value == null ? '—' : '${(value * 100).round()}%',
              style: NocturneType.title(
                value == null ? theme.faint : theme.ink,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(label, style: NocturneType.label(theme.faint)),
          const SizedBox(height: 2),
          Text(
            '${rate.recorded} logged',
            style: NocturneType.caption(theme.muted),
          ),
        ],
      ),
    );
  }
}

class _YearsCard extends StatelessWidget {
  const _YearsCard({required this.analytics});

  final LifeAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    return GlassCard(
      child: Column(
        children: <Widget>[
          _MetricRow(
            label: 'Completed days',
            value: _years(analytics.completedYears),
            color: theme.kept,
          ),
          const SizedBox(height: NocturneSpace.x4),
          _MetricRow(
            label: 'Outstanding practice',
            value: _years(analytics.outstandingYears),
            color: theme.missed,
          ),
          const SizedBox(height: NocturneSpace.x4),
          _MetricRow(
            label: 'Repaid practice',
            value: _years(analytics.repaidYears),
            color: theme.blue,
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    return Row(
      children: <Widget>[
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: NocturneSpace.x3),
        Expanded(child: Text(label, style: NocturneType.body(theme.muted))),
        Text(value, style: NocturneType.mono(theme.ink)),
      ],
    );
  }
}

class _ProjectionCard extends StatelessWidget {
  const _ProjectionCard({required this.analytics});

  final LifeAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    final weeks = analytics.projectedWeeksToClear;
    final title = weeks == 0
        ? 'No outstanding items'
        : weeks == null
        ? 'No repayment pace yet'
        : _durationLabel(weeks);
    final detail = weeks == 0
        ? 'Your personal make-up list is clear.'
        : weeks == null
        ? 'Complete an item to begin a rolling 90-day projection.'
        : 'At ${analytics.repaymentsPerWeek.toStringAsFixed(1)} items per week, based on your recent pace.';
    return GlassCard(
      tint: theme.blue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('PROJECTED CLEARANCE', style: NocturneType.label(theme.blue)),
          const SizedBox(height: NocturneSpace.x3),
          Text(title, style: NocturneType.cardTitle(theme.ink)),
          const SizedBox(height: NocturneSpace.x2),
          Text(detail, style: NocturneType.caption(theme.muted)),
        ],
      ),
    );
  }
}

class _MonthlyChart extends StatelessWidget {
  const _MonthlyChart({required this.months});

  final List<LifeMonthSummary> months;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MonthlyChartPainter(
        months: months,
        theme: NocturneScope.of(context),
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _MonthlyChartPainter extends CustomPainter {
  const _MonthlyChartPainter({required this.months, required this.theme});

  final List<LifeMonthSummary> months;
  final NocturneThemeData theme;

  @override
  void paint(Canvas canvas, Size size) {
    const labelHeight = 22.0;
    final plotHeight = size.height - labelHeight;
    final maxTotal = math.max(
      1,
      months.fold<int>(0, (value, month) => math.max(value, month.total)),
    );
    final slot = size.width / months.length;
    final barWidth = math.min(24.0, slot * 0.48);
    final paint = Paint()..style = PaintingStyle.fill;
    final labelPainter = TextPainter(textDirection: TextDirection.ltr);
    const labels = <String>[
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

    for (var index = 0; index < months.length; index++) {
      final month = months[index];
      final left = slot * index + (slot - barWidth) / 2;
      var bottom = plotHeight;
      for (final segment in <(int, Color)>[
        (month.completed, theme.kept),
        (month.repaid, theme.blue),
        (month.missed, theme.missed),
      ]) {
        if (segment.$1 == 0) continue;
        final height = plotHeight * segment.$1 / maxTotal;
        paint.color = segment.$2;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(left, bottom - height, barWidth, height),
            const Radius.circular(3),
          ),
          paint,
        );
        bottom -= height;
      }
      if (month.total == 0) {
        paint.color = theme.faint.withValues(alpha: 0.35);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(left, plotHeight - 2, barWidth, 2),
            const Radius.circular(2),
          ),
          paint,
        );
      }
      labelPainter.text = TextSpan(
        text: labels[month.month.month - 1],
        style: NocturneType.label(theme.faint),
      );
      labelPainter.layout();
      labelPainter.paint(
        canvas,
        Offset(slot * index + (slot - labelPainter.width) / 2, plotHeight + 8),
      );
    }
  }

  @override
  bool shouldRepaint(_MonthlyChartPainter oldDelegate) =>
      oldDelegate.months != months || oldDelegate.theme != theme;
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend();

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: NocturneSpace.x4,
      runSpacing: NocturneSpace.x2,
      children: <Widget>[
        _Legend(label: 'Completed', color: theme.kept),
        _Legend(label: 'Repaid', color: theme.blue),
        _Legend(label: 'Missed', color: theme.missed),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.label, required this.color});

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

String _years(double value) => '${value.toStringAsFixed(2)} years';

String _durationLabel(double weeks) {
  if (weeks < 8) return '${weeks.ceil()} weeks at this pace';
  final months = weeks / 4.345;
  if (months < 24) return '${months.toStringAsFixed(1)} months at this pace';
  return '${(weeks / 52.18).toStringAsFixed(1)} years at this pace';
}
