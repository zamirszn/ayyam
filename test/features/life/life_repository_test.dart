import 'package:ayyam/core/database/app_database.dart';
import 'package:ayyam/features/life/data/life_repository.dart';
import 'package:ayyam/features/life/domain/prayer_day.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('creates, advances and clears a dated make-up debt', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftLifeRepository(database);
    final day = DateTime(2026, 11, 2);

    await repository.recordDay(
      day: day,
      status: PrayerDayStatus.missed,
      recordedAt: DateTime(2026, 11, 2, 22),
    );
    var debts = await repository.allDebts();
    expect(debts, hasLength(1));
    expect(debts.single.sourceDay, day);

    final stepped = await repository.addDebtStep(
      debts.single.id,
      DateTime(2026, 11, 3),
    );
    expect(stepped.completedSteps, 1);
    final completed = await repository.completeDebt(
      stepped.id,
      DateTime(2026, 11, 3, 20),
    );
    expect(completed.isRepaid, isTrue);

    await repository.recordDay(
      day: day,
      status: PrayerDayStatus.completed,
      recordedAt: DateTime(2026, 11, 3, 21),
    );
    debts = await repository.allDebts();
    expect(debts, isEmpty);
    expect(
      (await repository.allPrayerDays()).single.status,
      PrayerDayStatus.completed,
    );
  });

  test('backfills dated misses and synchronizes undated estimates', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftLifeRepository(database);

    await repository.backfill(
      start: DateTime(2026, 10, 30),
      end: DateTime(2026, 11, 1),
      status: PrayerDayStatus.missed,
      recordedAt: DateTime(2026, 11, 3),
    );
    await repository.syncEstimatedDebtTarget(3, DateTime(2026, 11, 3));

    var debts = await repository.allDebts();
    expect(debts.where((debt) => debt.sourceDay != null), hasLength(3));
    expect(
      debts.where((debt) => debt.origin == MakeupDebtOrigin.estimatedPast),
      hasLength(3),
    );

    await repository.syncEstimatedDebtTarget(1, DateTime(2026, 11, 3));
    debts = await repository.allDebts();
    expect(
      debts.where((debt) => debt.origin == MakeupDebtOrigin.estimatedPast),
      hasLength(1),
    );
  });
}
