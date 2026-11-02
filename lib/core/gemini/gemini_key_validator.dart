import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

final geminiKeyValidatorProvider = Provider<GeminiKeyValidator>(
  (ref) => GeminiKeyValidator(),
);

enum GeminiKeyStatus { valid, invalid, unavailable }

class GeminiKeyValidator {
  GeminiKeyValidator({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<GeminiKeyStatus> validate(String apiKey) async {
    if (apiKey.trim().isEmpty) return GeminiKeyStatus.invalid;

    try {
      final response = await _client
          .get(
            Uri.https('generativelanguage.googleapis.com', '/v1beta/models'),
            headers: <String, String>{'x-goog-api-key': apiKey.trim()},
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) return GeminiKeyStatus.valid;
      if (<int>{400, 401, 403}.contains(response.statusCode)) {
        return GeminiKeyStatus.invalid;
      }
      return GeminiKeyStatus.unavailable;
    } on TimeoutException {
      return GeminiKeyStatus.unavailable;
    } on http.ClientException {
      return GeminiKeyStatus.unavailable;
    }
  }
}
