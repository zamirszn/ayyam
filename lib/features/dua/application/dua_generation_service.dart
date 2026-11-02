import 'package:ayyam/features/dua/data/dua_repository.dart';
import 'package:ayyam/features/dua/data/gemini_dua_client.dart';
import 'package:ayyam/features/dua/domain/dua.dart';
import 'package:ayyam/features/dua/domain/dua_identity.dart';
import 'package:ayyam/features/dua/domain/dua_validator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final duaValidatorProvider = Provider<DuaValidator>(
  (ref) => const DuaValidator(),
);

final duaGenerationServiceProvider = Provider<DuaGenerationService>((ref) {
  return DuaGenerationService(
    repository: ref.watch(duaRepositoryProvider),
    client: ref.watch(duaGeneratorClientProvider),
    validator: ref.watch(duaValidatorProvider),
  );
});

class DuaPreparationException implements Exception {
  const DuaPreparationException(this.message);

  final String message;

  @override
  String toString() => 'DuaPreparationException($message)';
}

class DuaGenerationService {
  DuaGenerationService({
    required DuaRepository repository,
    required DuaGeneratorClient client,
    required DuaValidator validator,
  }) : _repository = repository,
       _client = client,
       _validator = validator;

  final DuaRepository _repository;
  final DuaGeneratorClient _client;
  final DuaValidator _validator;

  static const List<String> _fallbackCategories = <String>[
    'guidance',
    'forgiveness',
    'gratitude',
    'protection',
    'steadfastness',
  ];

  Future<Dua> prepareForDate({
    required DateTime date,
    required String apiKey,
    required String language,
    DuaStatus status = DuaStatus.shown,
    DateTime Function()? now,
  }) async {
    final assignedDate = DateTime(date.year, date.month, date.day);
    final existing = await _repository.findAssignedTo(assignedDate);
    if (existing != null) return existing;

    final exclusions = await _repository.exclusionHints();
    final failures = <String>[];

    for (var attempt = 0; attempt < 5; attempt++) {
      final fallback = attempt == 4;
      final category = fallback
          ? _fallbackCategories[assignedDate.day % _fallbackCategories.length]
          : 'a broadly useful authentic daily supplication';
      GeneratedDuaCandidate candidate;
      try {
        candidate = await _client.generate(
          apiKey: apiKey,
          language: language,
          exclusionHints: exclusions,
          category: category,
          attempt: attempt,
        );
      } on DuaGenerationException catch (error) {
        if (const <DuaGenerationError>{
          DuaGenerationError.invalidKey,
          DuaGenerationError.rateLimited,
          DuaGenerationError.unavailable,
        }.contains(error.error)) {
          rethrow;
        }
        failures.add(error.message);
        continue;
      }

      final validation = _validator.validate(candidate);
      if (!validation.isValid) {
        failures.add(validation.errors.join(' '));
        continue;
      }

      final id = DuaIdentity.idForArabic(candidate.arabic);
      if (await _repository.containsId(id)) {
        exclusions.add('$id:${DuaIdentity.exclusionHint(candidate.arabic)}');
        failures.add('Gemini repeated a previously collected dua.');
        continue;
      }

      final generatedAt = (now ?? DateTime.now)();
      final dua = Dua(
        id: id,
        arabic: candidate.arabic.trim(),
        transliteration: candidate.transliteration.trim(),
        translation: candidate.translation.trim(),
        benefits: candidate.benefits.trim(),
        occasion: candidate.occasion?.trim(),
        sources: List<DuaSource>.unmodifiable(candidate.sources),
        assignedDate: assignedDate,
        status: status,
        generatedAt: generatedAt,
      );
      try {
        await _repository.save(dua);
        return dua;
      } catch (error, stackTrace) {
        final assigned = await _repository.findAssignedTo(assignedDate);
        if (assigned != null) return assigned;
        if (await _repository.containsId(id)) {
          exclusions.add('$id:${DuaIdentity.exclusionHint(candidate.arabic)}');
          failures.add('The generated dua collided with local data.');
          continue;
        }
        Error.throwWithStackTrace(error, stackTrace);
      }
    }

    throw DuaPreparationException(
      failures.isEmpty
          ? 'No valid sourced dua was returned.'
          : 'No valid sourced dua was returned. ${failures.last}',
    );
  }
}
