import 'package:flutter/foundation.dart';

enum PrayerDayStatus { completed, missed }

enum LifeDotState { unrecorded, completed, missed, repaid, remaining }

enum MakeupDebtOrigin { missedDay, estimatedPast }

@immutable
class PrayerDay {
  const PrayerDay({
    required this.day,
    required this.status,
    required this.estimated,
    required this.recordedAt,
  });

  final DateTime day;
  final PrayerDayStatus status;
  final bool estimated;
  final DateTime recordedAt;
}

@immutable
class MakeupDebt {
  const MakeupDebt({
    required this.id,
    required this.sourceDay,
    required this.origin,
    required this.completedSteps,
    required this.createdAt,
    required this.repaidAt,
  });

  final int id;
  final DateTime? sourceDay;
  final MakeupDebtOrigin origin;
  final int completedSteps;
  final DateTime createdAt;
  final DateTime? repaidAt;

  bool get isRepaid => repaidAt != null || completedSteps >= 5;

  MakeupDebt copyWith({int? completedSteps, DateTime? repaidAt}) {
    return MakeupDebt(
      id: id,
      sourceDay: sourceDay,
      origin: origin,
      completedSteps: completedSteps ?? this.completedSteps,
      createdAt: createdAt,
      repaidAt: repaidAt ?? this.repaidAt,
    );
  }
}

@immutable
class LifeDot {
  const LifeDot({
    required this.date,
    required this.state,
    required this.isToday,
    required this.estimated,
  });

  final DateTime date;
  final LifeDotState state;
  final bool isToday;
  final bool estimated;
}

@immutable
class LifeYear {
  const LifeYear({required this.age, required this.days});

  final int age;
  final List<LifeDot> days;
}

@immutable
class LifeSummary {
  const LifeSummary({
    required this.daysLived,
    required this.daysRemaining,
    required this.percentLived,
    required this.completedDays,
    required this.missedDays,
    required this.repaidDays,
    required this.outstandingDebts,
    required this.estimatedOutstandingDebts,
    required this.repaidDebts,
  });

  final int daysLived;
  final int daysRemaining;
  final double percentLived;
  final int completedDays;
  final int missedDays;
  final int repaidDays;
  final int outstandingDebts;
  final int estimatedOutstandingDebts;
  final int repaidDebts;
}

@immutable
class LifeDashboard {
  const LifeDashboard({
    required this.dateOfBirth,
    required this.today,
    required this.years,
    required this.prayerDays,
    required this.debts,
    required this.outstandingDebts,
    required this.summary,
  });

  final DateTime dateOfBirth;
  final DateTime today;
  final List<LifeYear> years;
  final List<PrayerDay> prayerDays;
  final List<MakeupDebt> debts;
  final List<MakeupDebt> outstandingDebts;
  final LifeSummary summary;

  PrayerDay? get todayEntry {
    for (final entry in prayerDays) {
      if (_sameDay(entry.day, today)) return entry;
    }
    return null;
  }

  LifeDot? dotFor(DateTime date) {
    for (final year in years) {
      for (final dot in year.days) {
        if (_sameDay(dot.date, date)) return dot;
      }
    }
    return null;
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
