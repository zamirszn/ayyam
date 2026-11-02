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
          if (!source.collection.toLowerCase().contains('quran')) {
            errors.add('A Quran source must name the Quran.');
          }
          if (!_validQuranReference(source.reference)) {
            errors.add('Quran references must use surah:ayah format.');
          }
          if ((source.grading ?? 'Quran').toLowerCase() != 'quran') {
            errors.add('Quran sources must use the Quran grading label.');
          }
        case DuaSourceType.hadith:
          if (source.collection.trim().length < 3 ||
              source.reference.trim().isEmpty) {
            errors.add('Hadith collection and reference are required.');
          }
          final grading = source.grading?.toLowerCase() ?? '';
          if (!grading.contains('sahih') && !grading.contains('hasan')) {
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
    return surah >= 1 &&
        surah <= 114 &&
        firstAyah >= 1 &&
        lastAyah >= firstAyah;
  }
}
