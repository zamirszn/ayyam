import 'package:ayyam/features/life/application/life_dashboard_controller.dart';
import 'package:ayyam/features/life/domain/prayer_day.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds an exact 100-year grid and derives dot states', () {
    final dashboard = const LifeDashboardService().build(
      dateOfBirth: DateTime(2000, 1, 1),
      today: DateTime(2000, 1, 3),
      prayerDays: <PrayerDay>[
        PrayerDay(
          day: DateTime(2000, 1, 2),
          status: PrayerDayStatus.completed,
          estimated: false,
          recordedAt: DateTime(2000, 1, 2, 22),
        ),
        PrayerDay(
          day: DateTime(2000, 1, 3),
          status: PrayerDayStatus.missed,
          estimated: false,
          recordedAt: DateTime(2000, 1, 3, 22),
        ),
      ],
      debts: <MakeupDebt>[
        MakeupDebt(
          id: 1,
          sourceDay: DateTime(2000, 1, 3),
          origin: MakeupDebtOrigin.missedDay,
          completedSteps: 5,
          createdAt: DateTime(2000, 1, 3),
          repaidAt: DateTime(2000, 1, 4),
        ),
        MakeupDebt(
          id: 2,
          sourceDay: null,
          origin: MakeupDebtOrigin.estimatedPast,
          completedSteps: 0,
          createdAt: DateTime(2000, 1, 3),
          repaidAt: null,
        ),
      ],
    );

    expect(dashboard.years, hasLength(100));
    expect(dashboard.years.first.days, hasLength(366));
    expect(dashboard.summary.daysLived, 3);
    expect(dashboard.summary.completedDays, 1);
    expect(dashboard.summary.missedDays, 1);
    expect(dashboard.summary.repaidDays, 1);
    expect(dashboard.summary.outstandingDebts, 1);
    expect(dashboard.summary.estimatedOutstandingDebts, 1);
    expect(
      dashboard.dotFor(DateTime(2000, 1, 1))?.state,
      LifeDotState.unrecorded,
    );
    expect(
      dashboard.dotFor(DateTime(2000, 1, 2))?.state,
      LifeDotState.completed,
    );
    expect(dashboard.dotFor(DateTime(2000, 1, 3))?.state, LifeDotState.repaid);
    expect(
      dashboard.dotFor(DateTime(2000, 1, 4))?.state,
      LifeDotState.remaining,
    );
  });
}
