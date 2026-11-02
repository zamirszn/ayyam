import 'dart:convert';

import 'package:ayyam/features/dua/data/gemini_dua_client.dart';
import 'package:ayyam/features/dua/domain/dua.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('requests structured JSON without putting the key in the URL', () async {
    final client = GeminiDuaClient(
      client: MockClient((request) async {
        expect(request.url.queryParameters, isEmpty);
        expect(request.headers['x-goog-api-key'], 'test-key');
        final body = jsonDecode(request.body) as Map<String, Object?>;
        final config = body['generationConfig']! as Map<String, Object?>;
        expect(config['responseMimeType'], 'application/json');
        expect(config['responseJsonSchema'], isA<Map<String, Object?>>());
        return http.Response(
          jsonEncode(<String, Object?>{
            'candidates': <Object?>[
              <String, Object?>{
                'content': <String, Object?>{
                  'parts': <Object?>[
                    <String, Object?>{'text': jsonEncode(_responseCandidate())},
                  ],
                },
              },
            ],
          }),
          200,
        );
      }),
    );

    final result = await client.generate(
      apiKey: 'test-key',
      language: 'English',
      exclusionHints: const <String>[],
      category: 'guidance',
      attempt: 0,
    );

    expect(result.arabic, 'رَبِّ زِدْنِي عِلْمًا');
    expect(result.sources.single.type, DuaSourceType.quran);
  });

  test('maps authentication failures without exposing the key', () async {
    final client = GeminiDuaClient(
      client: MockClient(
        (request) async => http.Response(
          jsonEncode(<String, Object?>{
            'error': <String, Object?>{'message': 'API key not valid.'},
          }),
          403,
        ),
      ),
    );

    await expectLater(
      client.generate(
        apiKey: 'secret-key',
        language: 'English',
        exclusionHints: const <String>[],
        category: 'guidance',
        attempt: 0,
      ),
      throwsA(
        isA<DuaGenerationException>()
            .having(
              (error) => error.error,
              'error',
              DuaGenerationError.invalidKey,
            )
            .having(
              (error) => error.toString().contains('secret-key'),
              'does not expose the key',
              isFalse,
            ),
      ),
    );
  });
}

Map<String, Object?> _responseCandidate() => <String, Object?>{
  'arabic': 'رَبِّ زِدْنِي عِلْمًا',
  'transliteration': 'Rabbi zidni ilma.',
  'translation': 'My Lord, increase me in knowledge.',
  'benefits': 'A Quranic request for an increase in knowledge.',
  'occasion': 'Learning',
  'sources': <Object?>[
    <String, Object?>{
      'type': 'quran',
      'collection': 'Quran',
      'reference': '20:114',
      'grading': 'Quran',
    },
  ],
};
