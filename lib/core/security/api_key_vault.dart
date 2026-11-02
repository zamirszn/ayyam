import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final apiKeyVaultProvider = Provider<ApiKeyVault>((ref) => ApiKeyVault());

class ApiKeyVault {
  ApiKeyVault({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const String _storageKey = 'ayyam.gemini.apiKey';

  final FlutterSecureStorage _secureStorage;
  String? _webSessionKey;

  Future<String?> read() async {
    if (kIsWeb) return _webSessionKey;
    return _secureStorage.read(key: _storageKey);
  }

  Future<void> write(String value) async {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      await delete();
      return;
    }
    if (kIsWeb) {
      _webSessionKey = normalized;
      return;
    }
    await _secureStorage.write(key: _storageKey, value: normalized);
  }

  Future<void> delete() async {
    if (kIsWeb) {
      _webSessionKey = null;
      return;
    }
    await _secureStorage.delete(key: _storageKey);
  }
}
