import 'package:ayyam/core/database/app_database.dart';
import 'package:ayyam/features/dua/data/dua_repository.dart';
import 'package:ayyam/features/dua/domain/dua.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('persists, restores and completes a dua', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = DriftDuaRepository(database);
    final dua = _sampleDua();

    await repository.save(dua);
    final restored = await repository.findAssignedTo(DateTime(2026, 11, 2));
    final completed = await repository.markRecited(
      dua.id,
      DateTime(2026, 11, 2, 7),
    );
    final flagged = await repository.flag(dua.id);

    expect(restored?.arabic, dua.arabic);
    expect(restored?.sources.single.reference, '20:114');
    expect(await repository.containsId(dua.id), isTrue);
    expect(await repository.exclusionHints(), isNotEmpty);
    expect(completed.status, DuaStatus.recited);
    expect(completed.recitedAt, DateTime(2026, 11, 2, 7));
    expect(flagged.flagged, isTrue);
  });
}

Dua _sampleDua() => Dua(
  id: 'knowledge-dua',
  arabic: 'رَبِّ زِدْنِي عِلْمًا',
  transliteration: 'Rabbi zidni ilma.',
  translation: 'My Lord, increase me in knowledge.',
  benefits: 'A Quranic request for an increase in knowledge.',
  occasion: 'Learning',
  sources: const <DuaSource>[
    DuaSource(
      type: DuaSourceType.quran,
      collection: 'Quran',
      reference: '20:114',
      grading: 'Quran',
    ),
  ],
  assignedDate: DateTime(2026, 11, 2),
  status: DuaStatus.shown,
  generatedAt: DateTime(2026, 11, 2, 6),
);
