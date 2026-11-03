import 'dart:convert';

import 'package:ayyam/core/database/app_database.dart';
import 'package:ayyam/core/database/app_database_provider.dart';
import 'package:ayyam/features/dua/domain/dua.dart';
import 'package:ayyam/features/dua/domain/dua_identity.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final duaRepositoryProvider = Provider<DuaRepository>((ref) {
  return DriftDuaRepository(ref.watch(appDatabaseProvider));
});

abstract interface class DuaRepository {
  Future<Dua?> findAssignedTo(DateTime date);

  Future<List<Dua>> findAssignedBetween(DateTime start, DateTime end);

  Future<bool> containsId(String id);

  Future<List<String>> exclusionHints({int limit = 200});

  Future<void> save(Dua dua);

  Future<Dua> markShown(String id);

  Future<Dua> flag(String id);

  Future<Dua> markRecited(String id, DateTime recitedAt);
}

class DriftDuaRepository implements DuaRepository {
  DriftDuaRepository(this._database);

  final AppDatabase _database;

  @override
  Future<Dua?> findAssignedTo(DateTime date) async {
    final query = _database.select(_database.duaRecords)
      ..where((row) => row.assignedDay.equals(_dayKey(date)));
    final record = await query.getSingleOrNull();
    return record == null ? null : _fromRecord(record);
  }

  @override
  Future<List<Dua>> findAssignedBetween(DateTime start, DateTime end) async {
    final query = _database.select(_database.duaRecords)
      ..where(
        (row) =>
            row.assignedDay.isBiggerOrEqualValue(_dayKey(start)) &
            row.assignedDay.isSmallerOrEqualValue(_dayKey(end)),
      )
      ..orderBy([(row) => OrderingTerm.asc(row.assignedDay)]);
    final records = await query.get();
    return records.map(_fromRecord).toList(growable: false);
  }

  @override
  Future<bool> containsId(String id) async {
    final query = _database.select(_database.duaRecords)
      ..where((row) => row.id.equals(id));
    return await query.getSingleOrNull() != null;
  }

  @override
  Future<List<String>> exclusionHints({int limit = 200}) async {
    final query = _database.select(_database.duaRecords)
      ..orderBy([(row) => OrderingTerm.desc(row.generatedAt)])
      ..limit(limit);
    final records = await query.get();
    return records
        .map(
          (record) =>
              '${record.id}:${DuaIdentity.exclusionHint(record.arabic)}',
        )
        .toList(growable: false);
  }

  @override
  Future<void> save(Dua dua) async {
    await _database
        .into(_database.duaRecords)
        .insert(
          DuaRecordsCompanion.insert(
            id: dua.id,
            arabic: dua.arabic,
            transliteration: dua.transliteration,
            translation: dua.translation,
            benefits: dua.benefits,
            occasion: Value(dua.occasion),
            sourcesJson: jsonEncode(
              dua.sources
                  .map((source) => source.toJson())
                  .toList(growable: false),
            ),
            assignedDay: _dayKey(dua.assignedDate),
            status: dua.status.name,
            generatedAt: dua.generatedAt,
            recitedAt: Value(dua.recitedAt),
            flagged: Value(dua.flagged),
          ),
        );
  }

  @override
  Future<Dua> markShown(String id) async {
    final updated =
        await (_database.update(_database.duaRecords)
              ..where((row) => row.id.equals(id)))
            .write(DuaRecordsCompanion(status: Value(DuaStatus.shown.name)));
    if (updated != 1) throw StateError('Dua not found: $id');
    final query = _database.select(_database.duaRecords)
      ..where((row) => row.id.equals(id));
    return _fromRecord(await query.getSingle());
  }

  @override
  Future<Dua> flag(String id) async {
    final updated =
        await (_database.update(_database.duaRecords)
              ..where((row) => row.id.equals(id)))
            .write(const DuaRecordsCompanion(flagged: Value(true)));
    if (updated != 1) throw StateError('Dua not found: $id');
    final query = _database.select(_database.duaRecords)
      ..where((row) => row.id.equals(id));
    return _fromRecord(await query.getSingle());
  }

  @override
  Future<Dua> markRecited(String id, DateTime recitedAt) async {
    final updated =
        await (_database.update(
          _database.duaRecords,
        )..where((row) => row.id.equals(id))).write(
          DuaRecordsCompanion(
            status: Value(DuaStatus.recited.name),
            recitedAt: Value(recitedAt),
          ),
        );
    if (updated != 1) throw StateError('Dua not found: $id');
    final query = _database.select(_database.duaRecords)
      ..where((row) => row.id.equals(id));
    return _fromRecord(await query.getSingle());
  }

  Dua _fromRecord(DuaRecord record) {
    final decodedSources = jsonDecode(record.sourcesJson);
    if (decodedSources is! List<Object?>) {
      throw const FormatException('Stored dua sources are malformed.');
    }
    return Dua(
      id: record.id,
      arabic: record.arabic,
      transliteration: record.transliteration,
      translation: record.translation,
      benefits: record.benefits,
      occasion: record.occasion,
      sources: decodedSources
          .map((source) {
            if (source is! Map<Object?, Object?>) {
              throw const FormatException('Stored dua source is malformed.');
            }
            return DuaSource.fromJson(
              source.map((key, value) => MapEntry(key.toString(), value)),
            );
          })
          .toList(growable: false),
      assignedDate: _parseDay(record.assignedDay),
      status: DuaStatus.values.byName(record.status),
      generatedAt: record.generatedAt,
      recitedAt: record.recitedAt,
      flagged: record.flagged,
    );
  }
}

class MemoryDuaRepository implements DuaRepository {
  MemoryDuaRepository([Iterable<Dua> initial = const <Dua>[]]) {
    for (final dua in initial) {
      _byId[dua.id] = dua;
    }
  }

  final Map<String, Dua> _byId = <String, Dua>{};

  List<Dua> get values => List<Dua>.unmodifiable(_byId.values);

  @override
  Future<Dua?> findAssignedTo(DateTime date) async {
    final normalized = _dateOnly(date);
    for (final dua in _byId.values) {
      if (_dateOnly(dua.assignedDate) == normalized) return dua;
    }
    return null;
  }

  @override
  Future<List<Dua>> findAssignedBetween(DateTime start, DateTime end) async {
    final first = _dateOnly(start);
    final last = _dateOnly(end);
    final matches = _byId.values.where((dua) {
      final assigned = _dateOnly(dua.assignedDate);
      return !assigned.isBefore(first) && !assigned.isAfter(last);
    }).toList()..sort((a, b) => a.assignedDate.compareTo(b.assignedDate));
    return List<Dua>.unmodifiable(matches);
  }

  @override
  Future<bool> containsId(String id) async => _byId.containsKey(id);

  @override
  Future<List<String>> exclusionHints({int limit = 200}) async {
    final sorted = _byId.values.toList()
      ..sort((a, b) => b.generatedAt.compareTo(a.generatedAt));
    return sorted
        .take(limit)
        .map((dua) => '${dua.id}:${DuaIdentity.exclusionHint(dua.arabic)}')
        .toList(growable: false);
  }

  @override
  Future<void> save(Dua dua) async {
    if (_byId.containsKey(dua.id) ||
        await findAssignedTo(dua.assignedDate) != null) {
      throw StateError('Duplicate dua or assigned date.');
    }
    _byId[dua.id] = dua;
  }

  @override
  Future<Dua> markShown(String id) async {
    final existing = _byId[id];
    if (existing == null) throw StateError('Dua not found: $id');
    final updated = existing.copyWith(status: DuaStatus.shown);
    _byId[id] = updated;
    return updated;
  }

  @override
  Future<Dua> flag(String id) async {
    final existing = _byId[id];
    if (existing == null) throw StateError('Dua not found: $id');
    final updated = existing.copyWith(flagged: true);
    _byId[id] = updated;
    return updated;
  }

  @override
  Future<Dua> markRecited(String id, DateTime recitedAt) async {
    final existing = _byId[id];
    if (existing == null) throw StateError('Dua not found: $id');
    final updated = existing.copyWith(
      status: DuaStatus.recited,
      recitedAt: recitedAt,
    );
    _byId[id] = updated;
    return updated;
  }
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

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
