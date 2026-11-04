import 'package:ayyam/features/dua/application/dua_share_service.dart';
import 'package:ayyam/features/dua/domain/dua.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats a shareable dua with attribution', () {
    final text = duaShareText(
      Dua(
        id: 'dua',
        arabic: 'رَبِّ زِدْنِي عِلْمًا',
        transliteration: 'Rabbi zidni ilma.',
        translation: 'My Lord, increase me in knowledge.',
        benefits: 'A request for knowledge.',
        occasion: 'Learning',
        sources: const <DuaSource>[
          DuaSource(
            type: DuaSourceType.quran,
            collection: 'Quran',
            reference: '20:114',
            grading: 'Quran',
          ),
        ],
        assignedDate: DateTime(2026, 11, 4),
        status: DuaStatus.shown,
        generatedAt: DateTime(2026, 11, 4),
      ),
    );

    expect(text, contains('رَبِّ زِدْنِي عِلْمًا'));
    expect(text, contains('Quran 20:114 · Quran'));
    expect(text, endsWith('Shared from Ayyam'));
  });
}
