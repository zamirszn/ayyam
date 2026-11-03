import 'package:ayyam/features/dua/application/dua_buffer_service.dart';
import 'package:ayyam/features/dua/application/dua_generation_service.dart';
import 'package:ayyam/features/dua/data/dua_repository.dart';
import 'package:ayyam/features/dua/domain/dua.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'fills every missing future day without replacing stored days',
    () async {
      final today = DateTime(2026, 11, 3);
      final existing = _duaFor(today.add(const Duration(days: 2)), 20);
      final repository = MemoryDuaRepository(<Dua>[existing]);
      final preparer = _RecordingPreparer(repository);
      final service = DuaBufferService(
        repository: repository,
        preparer: preparer,
      );

      final result = await service.topUp(
        today: today,
        apiKey: 'key',
        language: 'English',
      );

      expect(result.isFull, isTrue);
      expect(result.generatedCount, 4);
      expect(result.duas, hasLength(5));
      expect(result.duas[1].id, existing.id);
      expect(
        result.duas.every((dua) => dua.status == DuaStatus.scheduled),
        isTrue,
      );
      expect(
        result.duas.map((dua) => dua.assignedDate),
        orderedEquals(<DateTime>[
          DateTime(2026, 11, 4),
          DateTime(2026, 11, 5),
          DateTime(2026, 11, 6),
          DateTime(2026, 11, 7),
          DateTime(2026, 11, 8),
        ]),
      );
    },
  );

  test('keeps the partial offline buffer when generation fails', () async {
    final today = DateTime(2026, 11, 3);
    final repository = MemoryDuaRepository();
    final preparer = _RecordingPreparer(repository, failOnCall: 3);
    final service = DuaBufferService(
      repository: repository,
      preparer: preparer,
    );

    final result = await service.topUp(
      today: today,
      apiKey: 'key',
      language: 'English',
    );

    expect(result.isFull, isFalse);
    expect(result.generatedCount, 2);
    expect(result.duas, hasLength(2));
    expect(result.failure, isA<DuaPreparationException>());
  });
}

class _RecordingPreparer implements DuaPreparer {
  _RecordingPreparer(this.repository, {this.failOnCall});

  final DuaRepository repository;
  final int? failOnCall;
  int calls = 0;

  @override
  Future<Dua> prepareForDate({
    required DateTime date,
    required String apiKey,
    required String language,
    DuaStatus status = DuaStatus.shown,
    DateTime Function()? now,
  }) async {
    calls++;
    if (calls == failOnCall) {
      throw const DuaPreparationException('Offline.');
    }
    final dua = _duaFor(date, calls, status: status);
    await repository.save(dua);
    return dua;
  }
}

Dua _duaFor(DateTime date, int seed, {DuaStatus status = DuaStatus.scheduled}) {
  return Dua(
    id: 'dua-$seed-${date.toIso8601String()}',
    arabic: 'رَبَّنَا دُعَاء $seed',
    transliteration: 'Rabbana dua $seed.',
    translation: 'A sourced prayer $seed.',
    benefits: 'A test context.',
    occasion: 'General',
    sources: const <DuaSource>[
      DuaSource(
        type: DuaSourceType.quran,
        collection: 'Quran',
        reference: '2:201',
        grading: 'Quran',
      ),
    ],
    assignedDate: date,
    status: status,
    generatedAt: date,
  );
}
