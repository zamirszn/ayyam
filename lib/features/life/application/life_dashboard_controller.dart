import 'dart:math' as math;

import 'package:ayyam/core/settings/app_preferences.dart';
import 'package:ayyam/core/settings/app_preferences_controller.dart';
import 'package:ayyam/features/life/data/life_repository.dart';
import 'package:ayyam/features/life/domain/prayer_day.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final lifeNowProvider = Provider<DateTime>((ref) => DateTime.now());

final lifeDashboardServiceProvider = Provider<LifeDashboardService>(
  (ref) => const LifeDashboardService(),
);

final lifeDashboardProvider =
    AsyncNotifierProvider<LifeDashboardController, LifeDashboard>(
      LifeDashboardController.new,
    );

class LifeSetupException implements Exception {
  const LifeSetupException(this.message);

  final String message;

  @override
  String toString() => 'LifeSetupException($message)';
}

class LifeDashboardController extends AsyncNotifier<LifeDashboard> {
  @override
  Future<LifeDashboard> build() async {
    final preferences = await ref.watch(appPreferencesProvider.future);
    return _load(preferences);
  }

  Future<void> recordToday(PrayerDayStatus status) async {
    final now = ref.read(lifeNowProvider);
    await ref
        .read(lifeRepositoryProvider)
        .recordDay(day: now, status: status, recordedAt: now);
    await _refresh();
  }

  Future<void> backfill({
    required DateTime start,
    required DateTime end,
    required PrayerDayStatus status,
  }) async {
    final now = ref.read(lifeNowProvider);
    final today = _dateOnly(now);
    if (!_dateOnly(end).isBefore(today)) {
      throw ArgumentError('Backfill must end before today.');
    }
    await ref
        .read(lifeRepositoryProvider)
        .backfill(start: start, end: end, status: status, recordedAt: now);
    await _refresh();
  }

  Future<void> addDebtStep(int id) async {
    await ref
        .read(lifeRepositoryProvider)
        .addDebtStep(id, ref.read(lifeNowProvider));
    await _refresh();
  }

  Future<void> completeDebt(int id) async {
    await ref
        .read(lifeRepositoryProvider)
        .completeDebt(id, ref.read(lifeNowProvider));
    await _refresh();
  }

  Future<void> _refresh() async {
    state = const AsyncLoading<LifeDashboard>();
    state = await AsyncValue.guard(() async {
      final preferences = await ref.read(appPreferencesProvider.future);
      return _load(preferences);
    });
  }

  Future<LifeDashboard> _load(AppPreferences preferences) async {
    final birthDate = preferences.dateOfBirth;
    if (!preferences.lifeInDotsEnabled || birthDate == null) {
      throw const LifeSetupException(
        'Add a date of birth in Settings to use Life in Dots.',
      );
    }
    final repository = ref.read(lifeRepositoryProvider);
    final now = ref.read(lifeNowProvider);
    await repository.syncEstimatedDebtTarget(
      preferences.missedPrayerYears * 365,
      now,
    );
    final prayerDays = await repository.allPrayerDays();
    final debts = await repository.allDebts();
    return ref
        .read(lifeDashboardServiceProvider)
        .build(
          dateOfBirth: birthDate,
          today: now,
          prayerDays: prayerDays,
          debts: debts,
        );
  }
}

class LifeDashboardService {
  const LifeDashboardService();

  LifeDashboard build({
    required DateTime dateOfBirth,
    required DateTime today,
    required Iterable<PrayerDay> prayerDays,
    required Iterable<MakeupDebt> debts,
  }) {
    final birth = _dateOnly(dateOfBirth);
    final currentDay = _dateOnly(today);
    if (currentDay.isBefore(birth)) {
      throw ArgumentError('Date of birth must not be in the future.');
    }

    final prayerList = prayerDays.toList(growable: false);
    final debtList = debts.toList(growable: false);
    final prayerByDay = <String, PrayerDay>{
      for (final entry in prayerList) _dayKey(entry.day): entry,
    };
    final debtByDay = <String, MakeupDebt>{
      for (final debt in debtList)
        if (debt.sourceDay != null) _dayKey(debt.sourceDay!): debt,
    };

    final years = <LifeYear>[];
    var totalDays = 0;
    for (var age = 0; age < 100; age++) {
      final start = _anniversary(birth, birth.year + age);
      final end = _anniversary(birth, birth.year + age + 1);
      final dots = <LifeDot>[];
      for (var day = start; day.isBefore(end); day = _nextDay(day)) {
        final prayer = prayerByDay[_dayKey(day)];
        final debt = debtByDay[_dayKey(day)];
        final state = day.isAfter(currentDay)
            ? LifeDotState.remaining
            : switch (prayer?.status) {
                PrayerDayStatus.completed => LifeDotState.completed,
                PrayerDayStatus.missed =>
                  debt?.isRepaid == true
                      ? LifeDotState.repaid
                      : LifeDotState.missed,
                null => LifeDotState.unrecorded,
              };
        dots.add(
          LifeDot(
            date: day,
            state: state,
            isToday: _sameDay(day, currentDay),
            estimated: prayer?.estimated ?? false,
          ),
        );
      }
      totalDays += dots.length;
      years.add(LifeYear(age: age, days: List<LifeDot>.unmodifiable(dots)));
    }

    final lived = math.min(
      totalDays,
      _utcDay(currentDay).difference(_utcDay(birth)).inDays + 1,
    );
    final outstanding = debtList.where((debt) => !debt.isRepaid).toList()
      ..sort(_compareDebts);
    final completedDays = prayerList
        .where((entry) => entry.status == PrayerDayStatus.completed)
        .length;
    final missedDays = prayerList
        .where((entry) => entry.status == PrayerDayStatus.missed)
        .length;
    final repaidDays = prayerList.where((entry) {
      if (entry.status != PrayerDayStatus.missed) return false;
      return debtByDay[_dayKey(entry.day)]?.isRepaid ?? false;
    }).length;

    return LifeDashboard(
      dateOfBirth: birth,
      today: currentDay,
      years: List<LifeYear>.unmodifiable(years),
      prayerDays: List<PrayerDay>.unmodifiable(prayerList),
      debts: List<MakeupDebt>.unmodifiable(debtList),
      outstandingDebts: List<MakeupDebt>.unmodifiable(outstanding.take(100)),
      summary: LifeSummary(
        daysLived: lived,
        daysRemaining: math.max(0, totalDays - lived),
        percentLived: totalDays == 0 ? 0 : lived / totalDays,
        completedDays: completedDays,
        missedDays: missedDays,
        repaidDays: repaidDays,
        outstandingDebts: outstanding.length,
        estimatedOutstandingDebts: outstanding
            .where((debt) => debt.origin == MakeupDebtOrigin.estimatedPast)
            .length,
        repaidDebts: debtList.where((debt) => debt.isRepaid).length,
      ),
    );
  }
}

int _compareDebts(MakeupDebt a, MakeupDebt b) {
  if (a.sourceDay != null && b.sourceDay != null) {
    return a.sourceDay!.compareTo(b.sourceDay!);
  }
  if (a.sourceDay != null) return -1;
  if (b.sourceDay != null) return 1;
  return a.id.compareTo(b.id);
}

DateTime _anniversary(DateTime birth, int year) {
  final lastDay = DateTime(year, birth.month + 1, 0).day;
  return DateTime(year, birth.month, math.min(birth.day, lastDay));
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime _nextDay(DateTime value) =>
    DateTime(value.year, value.month, value.day + 1);

DateTime _utcDay(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day);

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _dayKey(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
