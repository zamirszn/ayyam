import 'dart:math' as math;

import 'package:ayyam/features/life/domain/prayer_day.dart';
import 'package:flutter/foundation.dart';

@immutable
class CompletionRate {
  const CompletionRate({required this.completed, required this.recorded});

  final int completed;
  final int recorded;

  double? get value => recorded == 0 ? null : completed / recorded;
}

@immutable
class LifeMonthSummary {
  const LifeMonthSummary({
    required this.month,
    required this.completed,
    required this.missed,
    required this.repaid,
  });

  final DateTime month;
  final int completed;
  final int missed;
  final int repaid;

  int get total => completed + missed + repaid;
}

@immutable
class LifeAnalytics {
  const LifeAnalytics({
    required this.last30Days,
    required this.lastYear,
    required this.lifetime,
    required this.months,
    required this.completedYears,
    required this.outstandingYears,
    required this.repaidYears,
    required this.repaymentsPerWeek,
    required this.projectedWeeksToClear,
  });

  final CompletionRate last30Days;
  final CompletionRate lastYear;
  final CompletionRate lifetime;
  final List<LifeMonthSummary> months;
  final double completedYears;
  final double outstandingYears;
  final double repaidYears;
  final double repaymentsPerWeek;
  final double? projectedWeeksToClear;
}

class LifeAnalyticsService {
  const LifeAnalyticsService();

  LifeAnalytics build(LifeDashboard dashboard) {
    final today = _dateOnly(dashboard.today);
    final datedDebts = <String, MakeupDebt>{
      for (final debt in dashboard.debts)
        if (debt.sourceDay != null) _dayKey(debt.sourceDay!): debt,
    };
    final months = List<LifeMonthSummary>.generate(6, (index) {
      final month = DateTime(today.year, today.month - (5 - index));
      var completed = 0;
      var missed = 0;
      var repaid = 0;
      for (final entry in dashboard.prayerDays) {
        if (entry.day.year != month.year || entry.day.month != month.month) {
          continue;
        }
        if (entry.status == PrayerDayStatus.completed) {
          completed++;
        } else if (datedDebts[_dayKey(entry.day)]?.isRepaid == true) {
          repaid++;
        } else {
          missed++;
        }
      }
      return LifeMonthSummary(
        month: month,
        completed: completed,
        missed: missed,
        repaid: repaid,
      );
    }, growable: false);

    final repaid = dashboard.debts.where((debt) => debt.isRepaid).toList();
    final paceStart = today.subtract(const Duration(days: 89));
    final recentRepaid = repaid
        .where((debt) {
          final repaidAt = debt.repaidAt;
          if (repaidAt == null) return false;
          final day = _dateOnly(repaidAt);
          return !day.isBefore(paceStart) && !day.isAfter(today);
        })
        .toList(growable: false);
    var repaymentsPerWeek = 0.0;
    if (recentRepaid.isNotEmpty) {
      final first = recentRepaid
          .map((debt) => _dateOnly(debt.repaidAt!))
          .reduce((a, b) => a.isBefore(b) ? a : b);
      final observedDays = today.difference(first).inDays + 1;
      final observedWeeks = math.max(1.0, observedDays / 7);
      repaymentsPerWeek = recentRepaid.length / observedWeeks;
    }

    final outstanding = dashboard.summary.outstandingDebts;
    return LifeAnalytics(
      last30Days: _rate(dashboard.prayerDays, today, 30),
      lastYear: _rate(dashboard.prayerDays, today, 365),
      lifetime: _rate(dashboard.prayerDays, today, null),
      months: List<LifeMonthSummary>.unmodifiable(months),
      completedYears: dashboard.summary.completedDays / 365.25,
      outstandingYears: outstanding / 365.25,
      repaidYears: dashboard.summary.repaidDebts / 365.25,
      repaymentsPerWeek: repaymentsPerWeek,
      projectedWeeksToClear: outstanding == 0
          ? 0
          : repaymentsPerWeek == 0
          ? null
          : outstanding / repaymentsPerWeek,
    );
  }
}

CompletionRate _rate(
  Iterable<PrayerDay> entries,
  DateTime today,
  int? trailingDays,
) {
  final first = trailingDays == null
      ? null
      : today.subtract(Duration(days: trailingDays - 1));
  var completed = 0;
  var recorded = 0;
  for (final entry in entries) {
    final day = _dateOnly(entry.day);
    if (day.isAfter(today) || (first != null && day.isBefore(first))) continue;
    recorded++;
    if (entry.status == PrayerDayStatus.completed) completed++;
  }
  return CompletionRate(completed: completed, recorded: recorded);
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String _dayKey(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
