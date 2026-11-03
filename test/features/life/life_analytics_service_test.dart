import 'package:ayyam/features/life/application/life_analytics_service.dart';
import 'package:ayyam/features/life/application/life_dashboard_controller.dart';
import 'package:ayyam/features/life/domain/prayer_day.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('derives rates, monthly states and a recent debt projection', () {
    final today = DateTime(2026, 11, 3);
    final dashboard = const LifeDashboardService().build(
      dateOfBirth: DateTime(2000),
      today: today,
      prayerDays: <PrayerDay>[
        _day(2026, 10, 1, PrayerDayStatus.completed),
        _day(2026, 10, 2, PrayerDayStatus.missed),
        _day(2026, 11, 1, PrayerDayStatus.completed),
        _day(2026, 11, 2, PrayerDayStatus.missed),
        _day(2026, 11, 3, PrayerDayStatus.completed),
      ],
      debts: <MakeupDebt>[
        MakeupDebt(
          id: 1,
          sourceDay: DateTime(2026, 10, 2),
          origin: MakeupDebtOrigin.missedDay,
          completedSteps: 5,
          createdAt: DateTime(2026, 10, 2),
          repaidAt: DateTime(2026, 10, 10),
        ),
        MakeupDebt(
          id: 2,
          sourceDay: DateTime(2026, 11, 2),
          origin: MakeupDebtOrigin.missedDay,
          completedSteps: 0,
          createdAt: DateTime(2026, 11, 2),
          repaidAt: null,
        ),
      ],
    );

    final analytics = const LifeAnalyticsService().build(dashboard);

    expect(analytics.last30Days.recorded, 3);
    expect(analytics.last30Days.value, closeTo(2 / 3, 0.001));
    expect(analytics.lastYear.recorded, 5);
    expect(analytics.lifetime.value, 0.6);
    expect(analytics.months[4].completed, 1);
    expect(analytics.months[4].repaid, 1);
    expect(analytics.months.last.completed, 2);
    expect(analytics.months.last.missed, 1);
    expect(analytics.repaymentsPerWeek, closeTo(0.28, 0.01));
    expect(analytics.projectedWeeksToClear, closeTo(3.57, 0.01));
  });
}

PrayerDay _day(int year, int month, int day, PrayerDayStatus status) {
  final date = DateTime(year, month, day);
  return PrayerDay(
    day: date,
    status: status,
    estimated: false,
    recordedAt: date,
  );
}
