import 'package:ayyam/features/dua/application/dua_library_service.dart';
import 'package:ayyam/features/dua/domain/dua.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('computes streaks without restoring late recitations', () {
    final today = DateTime(2026, 11, 3);
    final library = const DuaLibraryService().build(<Dua>[
      _dua(DateTime(2026, 10, 28), recitedAt: DateTime(2026, 10, 28, 7)),
      _dua(DateTime(2026, 10, 29), recitedAt: DateTime(2026, 10, 29, 7)),
      _dua(DateTime(2026, 10, 30)),
      _dua(DateTime(2026, 10, 31), recitedAt: DateTime(2026, 10, 31, 7)),
      _dua(DateTime(2026, 11, 1), recitedAt: DateTime(2026, 11, 1, 7)),
      _dua(DateTime(2026, 11, 2), recitedAt: DateTime(2026, 11, 3, 7)),
      _dua(today),
    ], today: today);

    expect(library.stats.current, 0);
    expect(library.stats.longest, 2);
    expect(library.stats.totalCollected, 5);
    expect(
      library.statusOf(library.assignedTo(DateTime(2026, 11, 2))!),
      DuaHistoryStatus.recitedLate,
    );
    expect(
      library.statusOf(library.assignedTo(DateTime(2026, 10, 30))!),
      DuaHistoryStatus.missed,
    );
  });

  test('keeps yesterday’s streak while today is still pending', () {
    final today = DateTime(2026, 11, 3);
    final library = const DuaLibraryService().build(<Dua>[
      _dua(DateTime(2026, 11, 1), recitedAt: DateTime(2026, 11, 1, 7)),
      _dua(DateTime(2026, 11, 2), recitedAt: DateTime(2026, 11, 2, 7)),
      _dua(today),
    ], today: today);

    expect(library.stats.current, 2);
    expect(library.stats.longest, 2);
  });

  test('searches the recited collection by source and occasion', () {
    final library = const DuaLibraryService().build(<Dua>[
      _dua(
        DateTime(2026, 11, 1),
        recitedAt: DateTime(2026, 11, 1, 7),
        occasion: 'Learning',
      ),
      _dua(
        DateTime(2026, 11, 2),
        recitedAt: DateTime(2026, 11, 2, 7),
        occasion: 'Travel',
        hadith: true,
      ),
    ], today: DateTime(2026, 11, 3));

    expect(
      library.searchCollection(query: 'knowledge').single.occasion,
      'Learning',
    );
    expect(
      library.searchCollection(source: DuaSourceFilter.hadith).single.occasion,
      'Travel',
    );
    expect(library.searchCollection(occasion: 'Learning'), hasLength(1));
  });
}

Dua _dua(
  DateTime assigned, {
  DateTime? recitedAt,
  String occasion = 'Learning',
  bool hadith = false,
}) {
  final status = recitedAt == null ? DuaStatus.shown : DuaStatus.recited;
  return Dua(
    id: '${assigned.toIso8601String()}-$occasion',
    arabic: 'رَبِّ زِدْنِي عِلْمًا',
    transliteration: 'Rabbi zidni ilma.',
    translation: hadith
        ? 'A prayer for safe travel.'
        : 'My Lord, increase me in knowledge.',
    benefits: 'A sourced context.',
    occasion: occasion,
    sources: <DuaSource>[
      if (hadith)
        const DuaSource(
          type: DuaSourceType.hadith,
          collection: 'Sahih Muslim',
          reference: '1342',
          grading: 'Sahih',
        )
      else
        const DuaSource(
          type: DuaSourceType.quran,
          collection: 'Quran',
          reference: '20:114',
          grading: 'Quran',
        ),
    ],
    assignedDate: assigned,
    status: status,
    generatedAt: assigned,
    recitedAt: recitedAt,
  );
}
