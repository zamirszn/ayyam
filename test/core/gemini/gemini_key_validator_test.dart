import 'package:ayyam/core/gemini/gemini_key_validator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('accepts a key when Gemini lists models', () async {
    final validator = GeminiKeyValidator(
      client: MockClient((request) async {
        expect(request.headers['x-goog-api-key'], 'test-key');
        return http.Response('{}', 200);
      }),
    );

    expect(await validator.validate('test-key'), GeminiKeyStatus.valid);
  });

  test('rejects authentication failures', () async {
    final validator = GeminiKeyValidator(
      client: MockClient((request) async => http.Response('{}', 403)),
    );

    expect(await validator.validate('bad-key'), GeminiKeyStatus.invalid);
  });

  test(
    'reports transient service failures without rejecting the key',
    () async {
      final validator = GeminiKeyValidator(
        client: MockClient((request) async => http.Response('{}', 503)),
      );

      expect(
        await validator.validate('unknown-key'),
        GeminiKeyStatus.unavailable,
      );
    },
  );
}
