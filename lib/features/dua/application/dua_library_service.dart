import 'package:ayyam/features/dua/data/dua_repository.dart';
import 'package:ayyam/features/dua/domain/dua.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final duaLibraryTodayProvider = Provider<DateTime>((ref) => DateTime.now());

final duaLibraryServiceProvider = Provider<DuaLibraryService>(
  (ref) => const DuaLibraryService(),
);

final duaLibraryProvider = FutureProvider<DuaLibrary>((ref) async {
  final records = await ref.watch(duaRepositoryProvider).all();
  return ref
      .watch(duaLibraryServiceProvider)
      .build(records, today: ref.watch(duaLibraryTodayProvider));
});

enum DuaHistoryStatus { recited, recitedLate, missed, pending, flagged }

enum DuaSourceFilter { all, quran, hadith }

@immutable
class DuaStreakStats {
  const DuaStreakStats({
    required this.current,
    required this.longest,
    required this.totalCollected,
    required this.totalAssigned,
  });

  final int current;
  final int longest;
  final int totalCollected;
  final int totalAssigned;
}

@immutable
class DuaLibrary {
  DuaLibrary({
    required this.today,
    required List<Dua> history,
    required List<Dua> collection,
    required this.stats,
  }) : history = List<Dua>.unmodifiable(history),
       collection = List<Dua>.unmodifiable(collection),
       occasions = List<String>.unmodifiable(_occasionValues(collection)),
       _byDay = <String, Dua>{
         for (final dua in history) _dayKey(dua.assignedDate): dua,
       };

  final DateTime today;
  final List<Dua> history;
  final List<Dua> collection;
  final List<String> occasions;
  final DuaStreakStats stats;
  final Map<String, Dua> _byDay;

  Dua? assignedTo(DateTime day) => _byDay[_dayKey(day)];

  DuaHistoryStatus statusOf(Dua dua) {
    if (dua.flagged) return DuaHistoryStatus.flagged;
    if (dua.isRecited) {
      return _wasRecitedOnAssignedDay(dua)
          ? DuaHistoryStatus.recited
          : DuaHistoryStatus.recitedLate;
    }
    return _dateOnly(dua.assignedDate).isBefore(today)
        ? DuaHistoryStatus.missed
        : DuaHistoryStatus.pending;
  }

  List<Dua> searchCollection({
    String query = '',
    DuaSourceFilter source = DuaSourceFilter.all,
    String? occasion,
  }) {
    final needle = query.trim().toLowerCase();
    final normalizedOccasion = occasion?.trim().toLowerCase();
    return collection
        .where((dua) {
          if (normalizedOccasion != null &&
              normalizedOccasion.isNotEmpty &&
              dua.occasion?.toLowerCase() != normalizedOccasion) {
            return false;
          }
          if (source != DuaSourceFilter.all &&
              !dua.sources.any((item) => item.type.name == source.name)) {
            return false;
          }
          if (needle.isEmpty) return true;
          final haystack = <String>[
            dua.arabic,
            dua.transliteration,
            dua.translation,
            dua.benefits,
            dua.occasion ?? '',
            for (final item in dua.sources) ...<String>[
              item.collection,
              item.reference,
              item.grading ?? '',
            ],
          ].join(' ').toLowerCase();
          return haystack.contains(needle);
        })
        .toList(growable: false);
  }
}

class DuaLibraryService {
  const DuaLibraryService();

  DuaLibrary build(Iterable<Dua> records, {required DateTime today}) {
    final currentDay = _dateOnly(today);
    final history =
        records
            .where((dua) => !_dateOnly(dua.assignedDate).isAfter(currentDay))
            .toList()
          ..sort((a, b) => b.assignedDate.compareTo(a.assignedDate));
    final collection =
        records.where((dua) => dua.isRecited && !dua.flagged).toList()
          ..sort((a, b) {
            final aDate = a.recitedAt ?? a.assignedDate;
            final bDate = b.recitedAt ?? b.assignedDate;
            return bDate.compareTo(aDate);
          });

    return DuaLibrary(
      today: currentDay,
      history: history,
      collection: collection,
      stats: _stats(history, collection, currentDay),
    );
  }

  DuaStreakStats _stats(
    List<Dua> history,
    List<Dua> collection,
    DateTime today,
  ) {
    if (history.isEmpty) {
      return DuaStreakStats(
        current: 0,
        longest: 0,
        totalCollected: collection.length,
        totalAssigned: 0,
      );
    }

    final byDay = <String, Dua>{
      for (final dua in history) _dayKey(dua.assignedDate): dua,
    };
    final earliest = history
        .map((dua) => _dateOnly(dua.assignedDate))
        .reduce((a, b) => a.isBefore(b) ? a : b);

    var longest = 0;
    var running = 0;
    for (var day = earliest; !day.isAfter(today); day = _nextDay(day)) {
      if (_wasRecitedOnAssignedDay(byDay[_dayKey(day)])) {
        running++;
        if (running > longest) longest = running;
      } else {
        running = 0;
      }
    }

    var current = 0;
    var cursor = _wasRecitedOnAssignedDay(byDay[_dayKey(today)])
        ? today
        : _previousDay(today);
    while (!cursor.isBefore(earliest) &&
        _wasRecitedOnAssignedDay(byDay[_dayKey(cursor)])) {
      current++;
      cursor = _previousDay(cursor);
    }

    return DuaStreakStats(
      current: current,
      longest: longest,
      totalCollected: collection.length,
      totalAssigned: history.length,
    );
  }
}

bool _wasRecitedOnAssignedDay(Dua? dua) {
  if (dua == null || !dua.isRecited || dua.recitedAt == null) return false;
  return _dayKey(dua.assignedDate) == _dayKey(dua.recitedAt!.toLocal());
}

List<String> _occasionValues(List<Dua> collection) {
  final values =
      collection
          .map((dua) => dua.occasion?.trim())
          .whereType<String>()
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return values;
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

DateTime _nextDay(DateTime value) =>
    DateTime(value.year, value.month, value.day + 1);

DateTime _previousDay(DateTime value) =>
    DateTime(value.year, value.month, value.day - 1);

String _dayKey(DateTime value) {
  final local = value.isUtc ? value.toLocal() : value;
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}
