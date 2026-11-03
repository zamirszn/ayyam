import 'dart:async';
import 'dart:convert';

import 'package:ayyam/features/dua/domain/dua.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

final duaGeneratorClientProvider = Provider<DuaGeneratorClient>((ref) {
  final httpClient = http.Client();
  ref.onDispose(httpClient.close);
  return GeminiDuaClient(client: httpClient);
});

enum DuaGenerationError {
  invalidKey,
  rateLimited,
  unavailable,
  refused,
  malformed,
}

class DuaGenerationException implements Exception {
  const DuaGenerationException(this.error, this.message);

  final DuaGenerationError error;
  final String message;

  @override
  String toString() => 'DuaGenerationException($error, $message)';
}

abstract interface class DuaGeneratorClient {
  Future<GeneratedDuaCandidate> generate({
    required String apiKey,
    required String language,
    required List<String> exclusionHints,
    required String category,
    required int attempt,
  });
}

class GeminiDuaClient implements DuaGeneratorClient {
  factory GeminiDuaClient({
    required http.Client client,
    String model = 'gemini-2.5-flash',
  }) => GeminiDuaClient._(client, model);

  GeminiDuaClient._(this._client, this.preferredModel);

  final http.Client _client;
  final String preferredModel;
  String? _resolvedModel;

  @override
  Future<GeneratedDuaCandidate> generate({
    required String apiKey,
    required String language,
    required List<String> exclusionHints,
    required String category,
    required int attempt,
  }) async {
    final normalizedKey = apiKey.trim();
    if (normalizedKey.isEmpty) {
      throw const DuaGenerationException(
        DuaGenerationError.invalidKey,
        'A Gemini API key is required.',
      );
    }

    final body = jsonEncode(<String, Object?>{
      'contents': <Object?>[
        <String, Object?>{
          'role': 'user',
          'parts': <Object?>[
            <String, Object?>{
              'text': _prompt(
                language: language,
                exclusionHints: exclusionHints,
                category: category,
                attempt: attempt,
              ),
            },
          ],
        },
      ],
      'generationConfig': <String, Object?>{
        'temperature': 0.15,
        'responseMimeType': 'application/json',
        'responseJsonSchema': _responseSchema,
      },
    });

    final model = _resolvedModel ?? await _discoverModel(normalizedKey);
    _resolvedModel = model;
    var response = await _postGeneration(
      apiKey: normalizedKey,
      model: model,
      body: body,
    );
    if (response.statusCode == 404) {
      final fallback = await _discoverModel(
        normalizedKey,
        excluded: <String>{model},
      );
      _resolvedModel = fallback;
      response = await _postGeneration(
        apiKey: normalizedKey,
        model: fallback,
        body: body,
      );
    }

    if (response.statusCode != 200) {
      throw _httpFailure(response);
    }

    try {
      final envelope = jsonDecode(response.body);
      if (envelope is! Map<Object?, Object?>) {
        throw const FormatException('Gemini response must be an object.');
      }
      final candidates = envelope['candidates'];
      if (candidates is! List<Object?> || candidates.isEmpty) {
        throw const DuaGenerationException(
          DuaGenerationError.refused,
          'Gemini did not return a content candidate.',
        );
      }
      final candidate = candidates.first;
      if (candidate is! Map<Object?, Object?>) {
        throw const FormatException('Candidate must be an object.');
      }
      final content = candidate['content'];
      if (content is! Map<Object?, Object?>) {
        throw const FormatException('Candidate content is missing.');
      }
      final parts = content['parts'];
      if (parts is! List<Object?> || parts.isEmpty) {
        throw const FormatException('Candidate text is missing.');
      }
      final text = parts
          .whereType<Map<Object?, Object?>>()
          .map((part) => part['text'])
          .whereType<String>()
          .join();
      final decoded = _decodeJsonObject(text);
      return GeneratedDuaCandidate.fromJson(decoded);
    } on DuaGenerationException {
      rethrow;
    } on FormatException catch (error) {
      throw DuaGenerationException(
        DuaGenerationError.malformed,
        'Gemini returned malformed structured content: ${error.message}',
      );
    }
  }

  Future<http.Response> _postGeneration({
    required String apiKey,
    required String model,
    required String body,
  }) async {
    final uri = Uri.https(
      'generativelanguage.googleapis.com',
      '/v1beta/models/$model:generateContent',
    );
    try {
      return await _client
          .post(
            uri,
            headers: <String, String>{
              'content-type': 'application/json',
              'x-goog-api-key': apiKey,
            },
            body: body,
          )
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      throw const DuaGenerationException(
        DuaGenerationError.unavailable,
        'Gemini did not respond in time.',
      );
    } on http.ClientException {
      throw const DuaGenerationException(
        DuaGenerationError.unavailable,
        'Gemini could not be reached.',
      );
    }
  }

  Future<String> _discoverModel(
    String apiKey, {
    Set<String> excluded = const <String>{},
  }) async {
    late http.Response response;
    try {
      response = await _client
          .get(
            Uri.https(
              'generativelanguage.googleapis.com',
              '/v1beta/models',
              const <String, String>{'pageSize': '1000'},
            ),
            headers: <String, String>{'x-goog-api-key': apiKey},
          )
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw const DuaGenerationException(
        DuaGenerationError.unavailable,
        'Gemini model discovery did not respond in time.',
      );
    } on http.ClientException {
      throw const DuaGenerationException(
        DuaGenerationError.unavailable,
        'Gemini model discovery could not be reached.',
      );
    }
    if (response.statusCode != 200) throw _httpFailure(response);
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<Object?, Object?>) {
        throw const FormatException('Model list must be an object.');
      }
      final rawModels = decoded['models'];
      if (rawModels is! List<Object?>) {
        throw const FormatException('Model list is missing.');
      }
      final available = <String>[];
      for (final rawModel in rawModels) {
        if (rawModel is! Map<Object?, Object?>) continue;
        final name = rawModel['name'];
        final methods = rawModel['supportedGenerationMethods'];
        if (name is! String || methods is! List<Object?>) continue;
        if (!methods.whereType<String>().contains('generateContent')) continue;
        final normalized = name.startsWith('models/')
            ? name.substring('models/'.length)
            : name;
        if (!excluded.contains(normalized) && _modelScore(normalized) >= 0) {
          available.add(normalized);
        }
      }
      if (available.contains(preferredModel)) return preferredModel;
      if (available.isEmpty) {
        throw const DuaGenerationException(
          DuaGenerationError.unavailable,
          'No Gemini text-generation model is available for this API key.',
        );
      }
      available.sort((a, b) => _modelScore(b).compareTo(_modelScore(a)));
      return available.first;
    } on DuaGenerationException {
      rethrow;
    } on FormatException catch (error) {
      throw DuaGenerationException(
        DuaGenerationError.malformed,
        'Gemini returned a malformed model list: ${error.message}',
      );
    }
  }

  int _modelScore(String name) {
    final normalized = name.toLowerCase();
    if (!normalized.startsWith('gemini-')) return -1;
    if (<String>[
      'embedding',
      'imagen',
      'image',
      'veo',
      'audio',
      'tts',
      'live',
      'robotics',
      'computer-use',
    ].any(normalized.contains)) {
      return -1;
    }
    var score = 0;
    if (normalized.contains('flash')) score += 100;
    if (normalized.contains('pro')) score += 50;
    if (normalized.contains('latest')) score += 20;
    if (normalized.contains('lite')) score -= 10;
    if (normalized.contains('preview')) score -= 15;
    if (normalized.contains('exp')) score -= 25;
    final version = RegExp(r'gemini-(\d+)(?:\.(\d+))?').firstMatch(normalized);
    if (version != null) {
      score += int.parse(version.group(1)!) * 10;
      score += int.tryParse(version.group(2) ?? '') ?? 0;
    }
    return score;
  }

  DuaGenerationException _httpFailure(http.Response response) {
    final message = _errorMessage(response.body);
    if (<int>{400, 401, 403}.contains(response.statusCode)) {
      return DuaGenerationException(
        DuaGenerationError.invalidKey,
        message ?? 'The Gemini API key was not accepted.',
      );
    }
    if (response.statusCode == 429) {
      return DuaGenerationException(
        DuaGenerationError.rateLimited,
        message ?? 'Gemini is rate-limiting requests.',
      );
    }
    return DuaGenerationException(
      DuaGenerationError.unavailable,
      message ?? 'Gemini is temporarily unavailable.',
    );
  }

  String? _errorMessage(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<Object?, Object?> &&
          decoded['error'] is Map<Object?, Object?>) {
        final error = decoded['error']! as Map<Object?, Object?>;
        final message = error['message'];
        return message is String ? message : null;
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  Map<String, Object?> _decodeJsonObject(String text) {
    var normalized = text.trim();
    if (normalized.startsWith('```')) {
      normalized = normalized
          .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
          .replaceFirst(RegExp(r'\s*```$'), '')
          .trim();
    }
    final decoded = jsonDecode(normalized);
    if (decoded is! Map<Object?, Object?>) {
      throw const FormatException('Structured content must be an object.');
    }
    return decoded.map((key, value) => MapEntry(key.toString(), value));
  }

  String _prompt({
    required String language,
    required List<String> exclusionHints,
    required String category,
    required int attempt,
  }) {
    final exclusions = exclusionHints.isEmpty
        ? 'None yet.'
        : exclusionHints.take(200).map((hint) => '- $hint').join('\n');
    return '''
You prepare one Islamic supplication for a private daily learning app.

Return only a supplication that is either:
1. directly from the Quran, or
2. from a hadith graded Sahih or Hasan.

Hard requirements:
- Preserve the sourced Arabic wording. Do not compose a new dua.
- Include full Arabic with tashkeel when reliably available.
- Translate into $language.
- State benefits or context only when supported by the cited source. Do not promise outcomes or invent virtues.
- For Quran, use collection "Quran", reference "surah:ayah", and grading "Quran".
- For hadith, name the collection, give its number/reference, and grading exactly "Sahih" or "Hasan".
- If attribution is uncertain, do not return that supplication.
- Do not repeat anything in the exclusion list.

Requested category: $category.
Generation attempt: ${attempt + 1}.

Already collected IDs and Arabic openings:
$exclusions
''';
  }

  static const Map<String, Object?> _responseSchema = <String, Object?>{
    'type': 'object',
    'additionalProperties': false,
    'required': <String>[
      'arabic',
      'transliteration',
      'translation',
      'benefits',
      'occasion',
      'sources',
    ],
    'properties': <String, Object?>{
      'arabic': <String, Object?>{'type': 'string'},
      'transliteration': <String, Object?>{'type': 'string'},
      'translation': <String, Object?>{'type': 'string'},
      'benefits': <String, Object?>{'type': 'string'},
      'occasion': <String, Object?>{'type': 'string'},
      'sources': <String, Object?>{
        'type': 'array',
        'minItems': 1,
        'maxItems': 5,
        'items': <String, Object?>{
          'type': 'object',
          'additionalProperties': false,
          'required': <String>['type', 'collection', 'reference', 'grading'],
          'properties': <String, Object?>{
            'type': <String, Object?>{
              'type': 'string',
              'enum': <String>['quran', 'hadith'],
            },
            'collection': <String, Object?>{'type': 'string'},
            'reference': <String, Object?>{'type': 'string'},
            'grading': <String, Object?>{
              'type': 'string',
              'enum': <String>['Quran', 'Sahih', 'Hasan'],
            },
          },
        },
      },
    },
  };
}
