import 'package:ayyam/features/dua/domain/dua.dart';
import 'package:ayyam/features/dua/domain/dua_identity.dart';

class DuaValidationResult {
  const DuaValidationResult(this.errors);

  final List<String> errors;

  bool get isValid => errors.isEmpty;
}

class DuaValidator {
  const DuaValidator();

  DuaValidationResult validate(GeneratedDuaCandidate candidate) {
    final errors = <String>[];
    final normalizedArabic = DuaIdentity.normalizeArabic(candidate.arabic);

    if (normalizedArabic.length < 5 ||
        !RegExp(r'[\u0621-\u064A]').hasMatch(candidate.arabic)) {
      errors.add('Arabic text is missing or malformed.');
    }
    _checkLength(
      candidate.arabic,
      field: 'Arabic text',
      maximum: 2000,
      errors: errors,
    );
    _checkLength(
      candidate.transliteration,
      field: 'Transliteration',
      maximum: 2000,
      errors: errors,
    );
    _checkLength(
      candidate.translation,
      field: 'Translation',
      maximum: 3000,
      errors: errors,
    );
    _checkLength(
      candidate.benefits,
      field: 'Benefits',
      maximum: 3000,
      errors: errors,
    );
    if ((candidate.occasion?.length ?? 0) > 120) {
      errors.add('Occasion is too long.');
    }
    if (candidate.sources.isEmpty) {
      errors.add('At least one source is required.');
    }
    if (candidate.sources.length > 5) {
      errors.add('Too many sources were returned.');
    }

    final seenSources = <String>{};
    for (final source in candidate.sources) {
      final key = '${source.collection}|${source.reference}'.toLowerCase();
      if (!seenSources.add(key)) {
        errors.add('The same source was returned more than once.');
      }
      switch (source.type) {
        case DuaSourceType.quran:
          final collection = source.collection.trim().toLowerCase();
          if (!const <String>{
            'quran',
            'the quran',
            'al-quran',
            'al quran',
          }.contains(collection)) {
            errors.add('A Quran source must name the Quran.');
          }
          if (!_validQuranReference(source.reference)) {
            errors.add('Quran reference is not a valid surah and ayah range.');
          }
          if ((source.grading ?? 'Quran').trim().toLowerCase() != 'quran') {
            errors.add('Quran sources must use the Quran grading label.');
          }
        case DuaSourceType.hadith:
          final collection = source.collection.trim();
          final reference = source.reference.trim();
          if (collection.length < 3 ||
              collection.length > 80 ||
              reference.isEmpty ||
              reference.length > 80 ||
              !RegExp(r'\d').hasMatch(reference)) {
            errors.add('Hadith collection and reference are required.');
          }
          final grading = source.grading?.trim().toLowerCase() ?? '';
          if (grading != 'sahih' && grading != 'hasan') {
            errors.add('Hadith grading must be Sahih or Hasan.');
          }
      }
    }

    return DuaValidationResult(List<String>.unmodifiable(errors));
  }

  void _checkLength(
    String value, {
    required String field,
    required int maximum,
    required List<String> errors,
  }) {
    if (value.trim().isEmpty) errors.add('$field is required.');
    if (value.length > maximum) errors.add('$field is too long.');
  }

  bool _validQuranReference(String value) {
    final match = RegExp(r'^(\d{1,3}):(\d{1,3})(?:-(\d{1,3}))?$')
        .firstMatch(value.trim());
    if (match == null) return false;
    final surah = int.parse(match.group(1)!);
    final firstAyah = int.parse(match.group(2)!);
    final lastAyah = int.tryParse(match.group(3) ?? '') ?? firstAyah;
    if (surah < 1 || surah > _quranVerseCounts.length) return false;
    final verseCount = _quranVerseCounts[surah - 1];
    return firstAyah >= 1 &&
        firstAyah <= verseCount &&
        lastAyah <= verseCount &&
        lastAyah >= firstAyah;
  }

  static const List<int> _quranVerseCounts = <int>[
    7,
    286,
    200,
    176,
    120,
    165,
    206,
    75,
    129,
    109,
    123,
    111,
    43,
    52,
    99,
    128,
    111,
    110,
    98,
    135,
    112,
    78,
    118,
    64,
    77,
    227,
    93,
    88,
    69,
    60,
    34,
    30,
    73,
    54,
    45,
    83,
    182,
    88,
    75,
    85,
    54,
    53,
    89,
    59,
    37,
    35,
    38,
    29,
    18,
    45,
    60,
    49,
    62,
    55,
    78,
    96,
    29,
    22,
    24,
    13,
    14,
    11,
    11,
    18,
    12,
    12,
    30,
    52,
    52,
    44,
    28,
    28,
    20,
    56,
    40,
    31,
    50,
    40,
    46,
    42,
    29,
    19,
    36,
    25,
    22,
    17,
    19,
    26,
    30,
    20,
    15,
    21,
    11,
    8,
    8,
    19,
    5,
    8,
    8,
    11,
    11,
    8,
    3,
    9,
    5,
    4,
    7,
    3,
    6,
    3,
    5,
    4,
    5,
    6,
  ];
}
