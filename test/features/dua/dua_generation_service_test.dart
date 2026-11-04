import 'package:ayyam/features/dua/application/dua_generation_service.dart';
import 'package:ayyam/features/dua/data/dua_repository.dart';
import 'package:ayyam/features/dua/data/gemini_dua_client.dart';
import 'package:ayyam/features/dua/domain/dua.dart';
import 'package:ayyam/features/dua/domain/dua_identity.dart';
import 'package:ayyam/features/dua/domain/dua_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('retries a duplicate and stores the next valid dua', () async {
    final previous = _persistedDua(
      candidate: _worldAndHereafterCandidate(),
      date: DateTime(2026, 11, 1),
    );
    final repository = MemoryDuaRepository(<Dua>[previous]);
    final client = _QueueDuaClient(<Object>[
      _worldAndHereafterCandidate(),
      _knowledgeCandidate(),
    ]);
    final service = DuaGenerationService(
      repository: repository,
      client: client,
      validator: const DuaValidator(),
    );

    final result = await service.prepareForDate(
      date: DateTime(2026, 11, 2),
      apiKey: 'test-key',
      language: 'English',
      now: () => DateTime(2026, 11, 2, 6),
    );

    expect(client.calls, 2);
    expect(result.id, DuaIdentity.idForArabic(_knowledgeCandidate().arabic));
    expect(repository.values, hasLength(2));
    expect(result.status, DuaStatus.shown);
  });

  test('rejects structurally unsafe content before storing', () async {
    final repository = MemoryDuaRepository();
    final invalid = GeneratedDuaCandidate(
      arabic: _knowledgeCandidate().arabic,
      transliteration: _knowledgeCandidate().transliteration,
      translation: _knowledgeCandidate().translation,
      benefits: _knowledgeCandidate().benefits,
      occasion: 'Learning',
      sources: const <DuaSource>[],
    );
    final client = _QueueDuaClient(<Object>[invalid, _knowledgeCandidate()]);
    final service = DuaGenerationService(
      repository: repository,
      client: client,
      validator: const DuaValidator(),
    );

    final result = await service.prepareForDate(
      date: DateTime(2026, 11, 2),
      apiKey: 'test-key',
      language: 'English',
    );

    expect(client.calls, 2);
    expect(result.sources, isNotEmpty);
    expect(repository.values, hasLength(1));
  });

  test('does not retry an invalid API key', () async {
    final client = _QueueDuaClient(<Object>[
      const DuaGenerationException(
        DuaGenerationError.invalidKey,
        'Rejected key.',
      ),
    ]);
    final service = DuaGenerationService(
      repository: MemoryDuaRepository(),
      client: client,
      validator: const DuaValidator(),
    );

    await expectLater(
      service.prepareForDate(
        date: DateTime(2026, 11, 2),
        apiKey: 'bad-key',
        language: 'English',
      ),
      throwsA(
        isA<DuaGenerationException>().having(
          (error) => error.error,
          'error',
          DuaGenerationError.invalidKey,
        ),
      ),
    );
    expect(client.calls, 1);
  });

  test(
    'retries refused generation and preserves the final fallback category',
    () async {
      final client = _QueueDuaClient(<Object>[
        const DuaGenerationException(
          DuaGenerationError.refused,
          'No content candidate was returned.',
        ),
        const DuaGenerationException(
          DuaGenerationError.malformed,
          'Structured content was malformed.',
        ),
        const DuaGenerationException(
          DuaGenerationError.refused,
          'No content candidate was returned.',
        ),
        const DuaGenerationException(
          DuaGenerationError.malformed,
          'Structured content was malformed.',
        ),
        _knowledgeCandidate(),
      ]);
      final service = DuaGenerationService(
        repository: MemoryDuaRepository(),
        client: client,
        validator: const DuaValidator(),
      );

      final result = await service.prepareForDate(
        date: DateTime(2026, 11, 2),
        apiKey: 'test-key',
        language: 'English',
      );

      expect(result.arabic, _knowledgeCandidate().arabic);
      expect(client.calls, 5);
      expect(client.categories.last, 'gratitude');
    },
  );
}

class _QueueDuaClient implements DuaGeneratorClient {
  _QueueDuaClient(this.responses);

  final List<Object> responses;
  int calls = 0;
  final List<String> categories = <String>[];

  @override
  Future<GeneratedDuaCandidate> generate({
    required String apiKey,
    required String language,
    required List<String> exclusionHints,
    required String category,
    required int attempt,
  }) async {
    categories.add(category);
    final response = responses[calls++];
    if (response is DuaGenerationException) throw response;
    return response as GeneratedDuaCandidate;
  }
}

Dua _persistedDua({
  required GeneratedDuaCandidate candidate,
  required DateTime date,
}) {
  return Dua(
    id: DuaIdentity.idForArabic(candidate.arabic),
    arabic: candidate.arabic,
    transliteration: candidate.transliteration,
    translation: candidate.translation,
    benefits: candidate.benefits,
    occasion: candidate.occasion,
    sources: candidate.sources,
    assignedDate: date,
    status: DuaStatus.recited,
    generatedAt: date,
    recitedAt: date,
  );
}

GeneratedDuaCandidate _knowledgeCandidate() {
  return const GeneratedDuaCandidate(
    arabic: 'رَبِّ زِدْنِي عِلْمًا',
    transliteration: 'Rabbi zidni ilma.',
    translation: 'My Lord, increase me in knowledge.',
    benefits: 'A Quranic request for an increase in knowledge.',
    occasion: 'Learning',
    sources: <DuaSource>[
      DuaSource(
        type: DuaSourceType.quran,
        collection: 'Quran',
        reference: '20:114',
        grading: 'Quran',
      ),
    ],
  );
}

GeneratedDuaCandidate _worldAndHereafterCandidate() {
  return const GeneratedDuaCandidate(
    arabic: 'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ',
    transliteration: 'Rabbana atina fid-dunya hasanatan wa fil-akhirati hasanatan wa qina adhaban-nar.',
    translation: 'Our Lord, give us good in this world and good in the Hereafter, and protect us from the torment of the Fire.',
    benefits: 'A Quranic supplication asking for good in both lives.',
    occasion: 'General',
    sources: <DuaSource>[
      DuaSource(
        type: DuaSourceType.quran,
        collection: 'Quran',
        reference: '2:201',
        grading: 'Quran',
      ),
    ],
  );
}
