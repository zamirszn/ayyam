import 'package:ayyam/design/components/glass_card.dart';
import 'package:ayyam/design/components/nocturne_button.dart';
import 'package:ayyam/design/components/nocturne_icon.dart';
import 'package:ayyam/design/components/nocturne_scaffold.dart';
import 'package:ayyam/design/theme/nocturne_theme.dart';
import 'package:ayyam/design/tokens/nocturne_tokens.dart';
import 'package:ayyam/design/type/nocturne_type.dart';
import 'package:ayyam/features/life/application/life_dashboard_controller.dart';
import 'package:ayyam/features/life/domain/prayer_day.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MakeupScreen extends ConsumerWidget {
  const MakeupScreen({super.key});

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
                Text('MAKE-UP / 006', style: NocturneType.label(theme.muted)),
              ],
            ),
            const SizedBox(height: NocturneSpace.x6),
            Expanded(
              child: dashboard.when(
                data: (value) => SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'A personal\npractice.',
                        style: NocturneType.hero(theme.ink, size: 50),
                      ),
                      const SizedBox(height: NocturneSpace.x4),
                      Text(
                        'Track five voluntary-prayer steps for each day you chose to address. This does not state that nafl replaces an obligatory prayer.',
                        style: NocturneType.body(theme.muted),
                      ),
                      const SizedBox(height: NocturneSpace.x6),
                      _DebtSummary(value: value),
                      const SizedBox(height: NocturneSpace.x8),
                      Text(
                        'OLDEST OUTSTANDING',
                        style: NocturneType.label(theme.muted),
                      ),
                      const SizedBox(height: NocturneSpace.x3),
                      if (value.outstandingDebts.isEmpty)
                        GlassCard(
                          tint: theme.kept,
                          child: Row(
                            children: <Widget>[
                              NocturneIcon(
                                NocturneGlyph.check,
                                color: theme.kept,
                              ),
                              const SizedBox(width: NocturneSpace.x3),
                              Expanded(
                                child: Text(
                                  'No make-up items are outstanding.',
                                  style: NocturneType.body(theme.muted),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        for (final debt in value.outstandingDebts) ...<Widget>[
                          _DebtCard(debt: debt),
                          const SizedBox(height: NocturneSpace.x3),
                        ],
                      if (value.summary.outstandingDebts >
                          value.outstandingDebts.length) ...<Widget>[
                        Text(
                          'Showing the oldest ${value.outstandingDebts.length} of ${value.summary.outstandingDebts} items.',
                          style: NocturneType.caption(theme.faint),
                        ),
                        const SizedBox(height: NocturneSpace.x4),
                      ],
                    ],
                  ),
                ),
                error: (error, stackTrace) => Center(
                  child: Text(
                    'Make-up records could not be read.',
                    style: NocturneType.body(theme.muted),
                  ),
                ),
                loading: () => Center(
                  child: Text(
                    'READING LOCAL PROGRESS…',
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

class _DebtSummary extends StatelessWidget {
  const _DebtSummary({required this.value});

  final LifeDashboard value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: _SummaryCard(
            value: '${value.summary.outstandingDebts}',
            label: 'OUTSTANDING',
          ),
        ),
        const SizedBox(width: NocturneSpace.x2),
        Expanded(
          child: _SummaryCard(
            value: '${value.summary.repaidDebts}',
            label: 'COMPLETED',
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = NocturneScope.of(context);
    return GlassCard(
      radius: NocturneRadius.medium,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      child: Column(
        children: <Widget>[
          Text(value, style: NocturneType.title(theme.ink)),
          Text(label, style: NocturneType.label(theme.faint)),
        ],
      ),
    );
  }
}

class _DebtCard extends ConsumerWidget {
  const _DebtCard({required this.debt});

  final MakeupDebt debt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = NocturneScope.of(context);
    return GlassCard(
      tint: debt.origin == MakeupDebtOrigin.estimatedPast
          ? theme.faint
          : theme.missed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  debt.sourceDay == null
                      ? 'Estimated past day'
                      : _dateLabel(debt.sourceDay!),
                  style: NocturneType.bodyStrong(theme.ink),
                ),
              ),
              Text(
                '${debt.completedSteps} / 5',
                style: NocturneType.label(theme.muted),
              ),
            ],
          ),
          const SizedBox(height: NocturneSpace.x3),
          Row(
            children: <Widget>[
              for (var step = 0; step < 5; step++) ...<Widget>[
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: step < debt.completedSteps
                        ? theme.kept
                        : theme.glass,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: step < debt.completedSteps
                          ? theme.kept
                          : theme.lineStrong,
                    ),
                  ),
                ),
                if (step != 4) const SizedBox(width: NocturneSpace.x2),
              ],
            ],
          ),
          const SizedBox(height: NocturneSpace.x4),
          Row(
            children: <Widget>[
              Expanded(
                child: NocturneButton(
                  label: 'Add one step',
                  style: NocturneButtonStyle.glass,
                  compact: true,
                  onTap: () {
                    ref
                        .read(lifeDashboardProvider.notifier)
                        .addDebtStep(debt.id);
                  },
                ),
              ),
              const SizedBox(width: NocturneSpace.x2),
              Expanded(
                child: NocturneButton(
                  label: 'Complete',
                  compact: true,
                  trailing: NocturneGlyph.check,
                  onTap: () {
                    ref
                        .read(lifeDashboardProvider.notifier)
                        .completeDebt(debt.id);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _dateLabel(DateTime value) {
  return '${value.day.toString().padLeft(2, '0')} / '
      '${value.month.toString().padLeft(2, '0')} / ${value.year}';
}
