import 'package:ayyam/features/dua/domain/dua.dart';
import 'package:ayyam/features/dua/domain/dua_identity.dart';
import 'package:ayyam/features/dua/domain/dua_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const validator = DuaValidator();

  test('accepts Quran content with a surah and ayah reference', () {
    final result = validator.validate(_quranCandidate());

    expect(result.isValid, isTrue);
    expect(result.errors, isEmpty);
  });

  test('rejects hadith without a Sahih or Hasan grading', () {
    final result = validator.validate(
      const GeneratedDuaCandidate(
        arabic: 'اللَّهُمَّ اهْدِنِي',
        transliteration: 'Allahumma ihdini.',
        translation: 'O Allah, guide me.',
        benefits: 'A request for guidance.',
        occasion: 'Guidance',
        sources: <DuaSource>[
          DuaSource(
            type: DuaSourceType.hadith,
            collection: 'Example collection',
            reference: '123',
            grading: 'Daif',
          ),
        ],
      ),
    );

    expect(result.isValid, isFalse);
    expect(result.errors, contains('Hadith grading must be Sahih or Hasan.'));
  });

  test('rejects misleading grading text that merely contains Sahih', () {
    final result = validator.validate(_hadithCandidate(grading: 'Not Sahih'));

    expect(result.isValid, isFalse);
    expect(result.errors, contains('Hadith grading must be Sahih or Hasan.'));
  });

  test('rejects a hadith source without a numbered reference', () {
    final result = validator.validate(
      _hadithCandidate(reference: 'Book of supplications'),
    );

    expect(result.isValid, isFalse);
    expect(
      result.errors,
      contains('Hadith collection and reference are required.'),
    );
  });

  test('rejects Quran ayahs beyond the selected surah', () {
    final result = validator.validate(_quranCandidate(reference: '1:8'));

    expect(result.isValid, isFalse);
    expect(
      result.errors,
      contains('Quran reference is not a valid surah and ayah range.'),
    );
  });

  test('normalizes tashkeel and spacing before hashing Arabic', () {
    final first = DuaIdentity.idForArabic('رَبِّ زِدْنِي عِلْمًا');
    final second = DuaIdentity.idForArabic('رب زدني علما');

    expect(first, second);
  });
}

GeneratedDuaCandidate _quranCandidate({String reference = '20:114'}) {
  return GeneratedDuaCandidate(
    arabic: 'رَبِّ زِدْنِي عِلْمًا',
    transliteration: 'Rabbi zidni ilma.',
    translation: 'My Lord, increase me in knowledge.',
    benefits: 'A Quranic request for an increase in knowledge.',
    occasion: 'Learning',
    sources: <DuaSource>[
      DuaSource(
        type: DuaSourceType.quran,
        collection: 'Quran',
        reference: reference,
        grading: 'Quran',
      ),
    ],
  );
}

GeneratedDuaCandidate _hadithCandidate({
  String reference = '123',
  String grading = 'Sahih',
}) {
  return GeneratedDuaCandidate(
    arabic: 'اللَّهُمَّ اهْدِنِي',
    transliteration: 'Allahumma ihdini.',
    translation: 'O Allah, guide me.',
    benefits: 'A request for guidance.',
    occasion: 'Guidance',
    sources: <DuaSource>[
      DuaSource(
        type: DuaSourceType.hadith,
        collection: 'Sahih Muslim',
        reference: reference,
        grading: grading,
      ),
    ],
  );
}
