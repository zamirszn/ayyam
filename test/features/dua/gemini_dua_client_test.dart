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
        expect(request.url.queryParameters, isNot(contains('key')));
        expect(request.headers['x-goog-api-key'], 'test-key');
        expect(
          request.url.path,
          '/v1beta/models/gemini-2.5-flash:generateContent',
        );
        final body = jsonDecode(request.body) as Map<String, Object?>;
        final config = body['generationConfig']! as Map<String, Object?>;
        expect(config['responseMimeType'], 'application/json');
        expect(config, isNot(contains('responseJsonSchema')));
        final schema = config['responseSchema']! as Map<String, Object?>;
        expect(schema['type'], 'OBJECT');
        return _generationResponse();
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

  test(
    'falls back to the stable alias and caches only the successful model',
    () async {
      final generationPaths = <String>[];
      final client = GeminiDuaClient(
        client: MockClient((request) async {
          generationPaths.add(request.url.path);
          if (request.url.path.contains('gemini-2.5-flash')) {
            return http.Response(
              jsonEncode(<String, Object?>{
                'error': <String, Object?>{'message': 'Model was not found.'},
              }),
              404,
            );
          }
          expect(
            request.url.path,
            '/v1beta/models/gemini-flash-latest:generateContent',
          );
          return _generationResponse();
        }),
      );

      final result = await client.generate(
        apiKey: 'test-key',
        language: 'English',
        exclusionHints: const <String>[],
        category: 'guidance',
        attempt: 0,
      );
      await client.generate(
        apiKey: 'test-key',
        language: 'English',
        exclusionHints: const <String>[],
        category: 'guidance',
        attempt: 1,
      );

      expect(result.arabic, 'رَبِّ زِدْنِي عِلْمًا');
      expect(generationPaths, <String>[
        '/v1beta/models/gemini-2.5-flash:generateContent',
        '/v1beta/models/gemini-flash-latest:generateContent',
        '/v1beta/models/gemini-flash-latest:generateContent',
      ]);
    },
  );

  test(
    'discovers another model when built-in choices are unavailable',
    () async {
      var generationCalls = 0;
      final client = GeminiDuaClient(
        client: MockClient((request) async {
          if (request.method == 'GET') {
            return http.Response(
              jsonEncode(
                _modelList(<String>['gemini-3.8-flash', 'gemini-3.7-flash']),
              ),
              200,
            );
          }
          generationCalls++;
          if (request.url.path.contains('gemini-2.5-flash') ||
              request.url.path.contains('gemini-flash-latest') ||
              request.url.path.contains('gemini-3.8-flash')) {
            return http.Response(
              jsonEncode(<String, Object?>{
                'error': <String, Object?>{
                  'message': 'The model is temporarily overloaded.',
                },
              }),
              503,
            );
          }
          expect(
            request.url.path,
            '/v1beta/models/gemini-3.7-flash:generateContent',
          );
          return _generationResponse();
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
      expect(generationCalls, 4);
    },
  );

  test('does not mistake a rejected request for an invalid API key', () async {
    final client = GeminiDuaClient(
      client: MockClient(
        (request) async => http.Response(
          jsonEncode(<String, Object?>{
            'error': <String, Object?>{
              'message': 'generationConfig.responseSchema is invalid.',
            },
          }),
          400,
        ),
      ),
    );

    await expectLater(
      client.generate(
        apiKey: 'valid-key',
        language: 'English',
        exclusionHints: const <String>[],
        category: 'guidance',
        attempt: 0,
      ),
      throwsA(
        isA<DuaGenerationException>().having(
          (error) => error.error,
          'error',
          DuaGenerationError.malformed,
        ),
      ),
    );
  });

  test('maps authentication failures without exposing the key', () async {
    final client = GeminiDuaClient(
      client: MockClient(
        (request) async => http.Response(
          jsonEncode(<String, Object?>{
            'error': <String, Object?>{
              'message': 'API key secret-key is not valid.',
            },
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

Map<String, Object?> _modelList(List<String> names) => <String, Object?>{
  'models': <Object?>[
    for (final name in names)
      <String, Object?>{
        'name': 'models/$name',
        'supportedGenerationMethods': <String>['generateContent'],
      },
  ],
};

http.Response _generationResponse() => http.Response(
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
  headers: const <String, String>{
    'content-type': 'application/json; charset=utf-8',
  },
);

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
