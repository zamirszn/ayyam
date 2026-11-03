import 'package:ayyam/core/database/app_database.dart';
import 'package:ayyam/core/database/app_database_provider.dart';
import 'package:ayyam/features/life/domain/prayer_day.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final lifeRepositoryProvider = Provider<LifeRepository>((ref) {
  return DriftLifeRepository(ref.watch(appDatabaseProvider));
});

abstract interface class LifeRepository {
  Future<List<PrayerDay>> allPrayerDays();

  Future<List<MakeupDebt>> allDebts();

  Future<PrayerDay> recordDay({
    required DateTime day,
    required PrayerDayStatus status,
    required DateTime recordedAt,
    bool estimated = false,
  });

  Future<void> backfill({
    required DateTime start,
    required DateTime end,
    required PrayerDayStatus status,
    required DateTime recordedAt,
  });

  Future<MakeupDebt> addDebtStep(int id, DateTime completedAt);

  Future<MakeupDebt> completeDebt(int id, DateTime completedAt);

  Future<void> syncEstimatedDebtTarget(int target, DateTime createdAt);
}

class DriftLifeRepository implements LifeRepository {
  const DriftLifeRepository(this._database);

  static const String _estimatedTargetKey = 'life.estimatedDebtTarget.v1';

  final AppDatabase _database;

  @override
  Future<List<PrayerDay>> allPrayerDays() async {
    final query = _database.select(_database.prayerDayRecords)
      ..orderBy([(row) => OrderingTerm.asc(row.day)]);
    return (await query.get()).map(_prayerFromRecord).toList(growable: false);
  }

  @override
  Future<List<MakeupDebt>> allDebts() async {
    final query = _database.select(_database.makeupDebtRecords)
      ..orderBy([(row) => OrderingTerm.asc(row.id)]);
    final debts = (await query.get()).map(_debtFromRecord).toList();
    debts.sort(_compareDebts);
    return List<MakeupDebt>.unmodifiable(debts);
  }

  @override
  Future<PrayerDay> recordDay({
    required DateTime day,
    required PrayerDayStatus status,
    required DateTime recordedAt,
    bool estimated = false,
  }) async {
    final normalized = _dateOnly(day);
    await _database.transaction(() async {
      await _writePrayerDay(
        day: normalized,
        status: status,
        recordedAt: recordedAt,
        estimated: estimated,
      );
    });
    final query = _database.select(_database.prayerDayRecords)
      ..where((row) => row.day.equals(_dayKey(normalized)));
    return _prayerFromRecord(await query.getSingle());
  }

  @override
  Future<void> backfill({
    required DateTime start,
    required DateTime end,
    required PrayerDayStatus status,
    required DateTime recordedAt,
  }) async {
    final first = _dateOnly(start);
    final last = _dateOnly(end);
    if (last.isBefore(first)) {
      throw ArgumentError('Backfill end must not be before its start.');
    }
    final days = <DateTime>[];
    for (var day = first; !day.isAfter(last); day = _nextDay(day)) {
      days.add(day);
    }

    await _database.transaction(() async {
      await _database.batch((batch) {
        batch.insertAllOnConflictUpdate(
          _database.prayerDayRecords,
          <PrayerDayRecordsCompanion>[
            for (final day in days)
              PrayerDayRecordsCompanion.insert(
                day: _dayKey(day),
                status: status.name,
                estimated: const Value(true),
                recordedAt: recordedAt,
              ),
          ],
        );
        if (status == PrayerDayStatus.missed) {
          batch.insertAll(
            _database.makeupDebtRecords,
            <MakeupDebtRecordsCompanion>[
              for (final day in days)
                MakeupDebtRecordsCompanion.insert(
                  sourceDay: Value(_dayKey(day)),
                  origin: MakeupDebtOrigin.missedDay.name,
                  createdAt: recordedAt,
                ),
            ],
            mode: InsertMode.insertOrIgnore,
          );
        }
      });
      if (status == PrayerDayStatus.completed) {
        for (final chunk in _chunks(days.map(_dayKey).toList(), 500)) {
          await (_database.delete(
            _database.makeupDebtRecords,
          )..where((row) => row.sourceDay.isIn(chunk))).go();
        }
      }
    });
  }

  @override
  Future<MakeupDebt> addDebtStep(int id, DateTime completedAt) async {
    final debt = await _debtById(id);
    if (debt.isRepaid) return debt;
    final steps = (debt.completedSteps + 1).clamp(0, 5);
    return _updateDebt(
      id,
      steps: steps,
      repaidAt: steps >= 5 ? completedAt : null,
    );
  }

  @override
  Future<MakeupDebt> completeDebt(int id, DateTime completedAt) {
    return _updateDebt(id, steps: 5, repaidAt: completedAt);
  }

  @override
  Future<void> syncEstimatedDebtTarget(int target, DateTime createdAt) async {
    if (target < 0) throw ArgumentError.value(target, 'target');
    final storedTarget = await _metadata(_estimatedTargetKey);
    if (storedTarget == '$target') return;

    await _database.transaction(() async {
      final query = _database.select(_database.makeupDebtRecords)
        ..where((row) => row.origin.equals(MakeupDebtOrigin.estimatedPast.name))
        ..orderBy([(row) => OrderingTerm.desc(row.id)]);
      final estimated = await query.get();
      final difference = target - estimated.length;
      if (difference > 0) {
        await _database.batch((batch) {
          batch.insertAll(
            _database.makeupDebtRecords,
            List<MakeupDebtRecordsCompanion>.generate(
              difference,
              (_) => MakeupDebtRecordsCompanion.insert(
                origin: MakeupDebtOrigin.estimatedPast.name,
                createdAt: createdAt,
              ),
              growable: false,
            ),
          );
        });
      } else if (difference < 0) {
        final removable = estimated
            .where((record) => record.repaidAt == null)
            .take(-difference)
            .map((record) => record.id)
            .toList(growable: false);
        for (final chunk in _chunks(removable, 500)) {
          await (_database.delete(
            _database.makeupDebtRecords,
          )..where((row) => row.id.isIn(chunk))).go();
        }
      }

      await _database
          .into(_database.lifeMetadataRecords)
          .insertOnConflictUpdate(
            LifeMetadataRecordsCompanion.insert(
              key: _estimatedTargetKey,
              value: '$target',
            ),
          );
    });
  }

  Future<void> _writePrayerDay({
    required DateTime day,
    required PrayerDayStatus status,
    required DateTime recordedAt,
    required bool estimated,
  }) async {
    final key = _dayKey(day);
    await _database
        .into(_database.prayerDayRecords)
        .insertOnConflictUpdate(
          PrayerDayRecordsCompanion.insert(
            day: key,
            status: status.name,
            estimated: Value(estimated),
            recordedAt: recordedAt,
          ),
        );
    if (status == PrayerDayStatus.missed) {
      await _database
          .into(_database.makeupDebtRecords)
          .insert(
            MakeupDebtRecordsCompanion.insert(
              sourceDay: Value(key),
              origin: MakeupDebtOrigin.missedDay.name,
              createdAt: recordedAt,
            ),
            mode: InsertMode.insertOrIgnore,
          );
    } else {
      await (_database.delete(
        _database.makeupDebtRecords,
      )..where((row) => row.sourceDay.equals(key))).go();
    }
  }

  Future<MakeupDebt> _debtById(int id) async {
    final query = _database.select(_database.makeupDebtRecords)
      ..where((row) => row.id.equals(id));
    final record = await query.getSingleOrNull();
    if (record == null) throw StateError('Make-up debt not found: $id');
    return _debtFromRecord(record);
  }

  Future<MakeupDebt> _updateDebt(
    int id, {
    required int steps,
    DateTime? repaidAt,
  }) async {
    final updated =
        await (_database.update(
          _database.makeupDebtRecords,
        )..where((row) => row.id.equals(id))).write(
          MakeupDebtRecordsCompanion(
            completedSteps: Value(steps.clamp(0, 5)),
            repaidAt: repaidAt == null ? const Value.absent() : Value(repaidAt),
          ),
        );
    if (updated != 1) throw StateError('Make-up debt not found: $id');
    return _debtById(id);
  }

  Future<String?> _metadata(String key) async {
    final query = _database.select(_database.lifeMetadataRecords)
      ..where((row) => row.key.equals(key));
    return (await query.getSingleOrNull())?.value;
  }

  PrayerDay _prayerFromRecord(PrayerDayRecord record) {
    return PrayerDay(
      day: _parseDay(record.day),
      status: PrayerDayStatus.values.byName(record.status),
      estimated: record.estimated,
      recordedAt: record.recordedAt,
    );
  }

  MakeupDebt _debtFromRecord(MakeupDebtRecord record) {
    return MakeupDebt(
      id: record.id,
      sourceDay: record.sourceDay == null ? null : _parseDay(record.sourceDay!),
      origin: MakeupDebtOrigin.values.byName(record.origin),
      completedSteps: record.completedSteps,
      createdAt: record.createdAt,
      repaidAt: record.repaidAt,
    );
  }
}

class MemoryLifeRepository implements LifeRepository {
  final Map<String, PrayerDay> _prayerDays = <String, PrayerDay>{};
  final Map<int, MakeupDebt> _debts = <int, MakeupDebt>{};
  int _nextDebtId = 1;
  int? _estimatedTarget;

  @override
  Future<List<PrayerDay>> allPrayerDays() async {
    final values = _prayerDays.values.toList()
      ..sort((a, b) => a.day.compareTo(b.day));
    return List<PrayerDay>.unmodifiable(values);
  }

  @override
  Future<List<MakeupDebt>> allDebts() async {
    final values = _debts.values.toList()..sort(_compareDebts);
    return List<MakeupDebt>.unmodifiable(values);
  }

  @override
  Future<PrayerDay> recordDay({
    required DateTime day,
    required PrayerDayStatus status,
    required DateTime recordedAt,
    bool estimated = false,
  }) async {
    final normalized = _dateOnly(day);
    final entry = PrayerDay(
      day: normalized,
      status: status,
      estimated: estimated,
      recordedAt: recordedAt,
    );
    _prayerDays[_dayKey(normalized)] = entry;
    final matching = _debts.values
        .where(
          (debt) => debt.sourceDay != null && _sameDay(debt.sourceDay!, day),
        )
        .map((debt) => debt.id)
        .toList();
    if (status == PrayerDayStatus.completed) {
      for (final id in matching) {
        _debts.remove(id);
      }
    } else if (matching.isEmpty) {
      _insertDebt(
        sourceDay: normalized,
        origin: MakeupDebtOrigin.missedDay,
        createdAt: recordedAt,
      );
    }
    return entry;
  }

  @override
  Future<void> backfill({
    required DateTime start,
    required DateTime end,
    required PrayerDayStatus status,
    required DateTime recordedAt,
  }) async {
    final first = _dateOnly(start);
    final last = _dateOnly(end);
    if (last.isBefore(first)) throw ArgumentError('Invalid backfill range.');
    for (var day = first; !day.isAfter(last); day = _nextDay(day)) {
      await recordDay(
        day: day,
        status: status,
        recordedAt: recordedAt,
        estimated: true,
      );
    }
  }

  @override
  Future<MakeupDebt> addDebtStep(int id, DateTime completedAt) async {
    final debt = _debts[id];
    if (debt == null) throw StateError('Make-up debt not found: $id');
    if (debt.isRepaid) return debt;
    final steps = (debt.completedSteps + 1).clamp(0, 5);
    final updated = debt.copyWith(
      completedSteps: steps,
      repaidAt: steps == 5 ? completedAt : null,
    );
    _debts[id] = updated;
    return updated;
  }

  @override
  Future<MakeupDebt> completeDebt(int id, DateTime completedAt) async {
    final debt = _debts[id];
    if (debt == null) throw StateError('Make-up debt not found: $id');
    final updated = debt.copyWith(completedSteps: 5, repaidAt: completedAt);
    _debts[id] = updated;
    return updated;
  }

  @override
  Future<void> syncEstimatedDebtTarget(int target, DateTime createdAt) async {
    if (_estimatedTarget == target) return;
    final estimated =
        _debts.values
            .where((debt) => debt.origin == MakeupDebtOrigin.estimatedPast)
            .toList()
          ..sort((a, b) => b.id.compareTo(a.id));
    final difference = target - estimated.length;
    if (difference > 0) {
      for (var index = 0; index < difference; index++) {
        _insertDebt(
          sourceDay: null,
          origin: MakeupDebtOrigin.estimatedPast,
          createdAt: createdAt,
        );
      }
    } else if (difference < 0) {
      for (final debt
          in estimated.where((debt) => !debt.isRepaid).take(-difference)) {
        _debts.remove(debt.id);
      }
    }
    _estimatedTarget = target;
  }

  void _insertDebt({
    required DateTime? sourceDay,
    required MakeupDebtOrigin origin,
    required DateTime createdAt,
  }) {
    final debt = MakeupDebt(
      id: _nextDebtId++,
      sourceDay: sourceDay,
      origin: origin,
      completedSteps: 0,
      createdAt: createdAt,
      repaidAt: null,
    );
    _debts[debt.id] = debt;
  }
}

int _compareDebts(MakeupDebt a, MakeupDebt b) {
  if (a.isRepaid != b.isRepaid) return a.isRepaid ? 1 : -1;
  if (a.sourceDay != null && b.sourceDay != null) {
    return a.sourceDay!.compareTo(b.sourceDay!);
  }
  if (a.sourceDay != null) return -1;
  if (b.sourceDay != null) return 1;
  return a.id.compareTo(b.id);
}

Iterable<List<T>> _chunks<T>(List<T> values, int size) sync* {
  for (var start = 0; start < values.length; start += size) {
    final end = (start + size).clamp(0, values.length);
    yield values.sublist(start, end);
  }
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime _nextDay(DateTime value) =>
    DateTime(value.year, value.month, value.day + 1);

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _dayKey(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

DateTime _parseDay(String value) {
  final parts = value.split('-');
  if (parts.length != 3) throw FormatException('Invalid day key: $value');
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}
