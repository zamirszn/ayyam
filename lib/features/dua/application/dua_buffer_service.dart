import 'package:ayyam/features/dua/application/dua_generation_service.dart';
import 'package:ayyam/features/dua/data/dua_repository.dart';
import 'package:ayyam/features/dua/domain/dua.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final duaBufferServiceProvider = Provider<DuaBufferService>((ref) {
  return DuaBufferService(
    repository: ref.watch(duaRepositoryProvider),
    preparer: ref.watch(duaGenerationServiceProvider),
  );
});

@immutable
class DuaBufferResult {
  const DuaBufferResult({
    required this.duas,
    required this.generatedCount,
    required this.requestedDays,
    this.failure,
  });

  final List<Dua> duas;
  final int generatedCount;
  final int requestedDays;
  final Object? failure;

  bool get isFull => duas.length >= requestedDays;
}

class DuaBufferService {
  factory DuaBufferService({
    required DuaRepository repository,
    required DuaPreparer preparer,
  }) => DuaBufferService._(repository, preparer);

  const DuaBufferService._(this._repository, this._preparer);

  final DuaRepository _repository;
  final DuaPreparer _preparer;

  Future<DuaBufferResult> topUp({
    required DateTime today,
    required String apiKey,
    required String language,
    int futureDays = 5,
  }) async {
    if (futureDays < 1) {
      throw ArgumentError.value(futureDays, 'futureDays', 'Must be positive.');
    }

    final firstDay = _dateOnly(today).add(const Duration(days: 1));
    final lastDay = firstDay.add(Duration(days: futureDays - 1));
    var generatedCount = 0;
    Object? failure;

    for (var offset = 0; offset < futureDays; offset++) {
      final date = firstDay.add(Duration(days: offset));
      if (await _repository.findAssignedTo(date) != null) continue;
      try {
        await _preparer.prepareForDate(
          date: date,
          apiKey: apiKey,
          language: language,
          status: DuaStatus.scheduled,
        );
        generatedCount++;
      } catch (error) {
        failure = error;
        break;
      }
    }

    final duas = await _repository.findAssignedBetween(firstDay, lastDay);
    return DuaBufferResult(
      duas: List<Dua>.unmodifiable(duas),
      generatedCount: generatedCount,
      requestedDays: futureDays,
      failure: failure,
    );
  }
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
