import 'dart:convert';

import 'package:crypto/crypto.dart';

abstract final class DuaIdentity {
  static final RegExp _diacritics = RegExp(
    r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED]',
  );
  static final RegExp _nonArabic = RegExp(
    r'[^\u0621-\u063A\u0641-\u064A\u066E-\u06D3]',
  );

  static String normalizeArabic(String value) {
    return value
        .replaceAll(_diacritics, '')
        .replaceAll('\u0640', '')
        .replaceAll(_nonArabic, '');
  }

  static String idForArabic(String value) {
    final normalized = normalizeArabic(value);
    return sha256.convert(utf8.encode(normalized)).toString();
  }

  static String exclusionHint(String value, {int wordCount = 6}) {
    final readable = value
        .replaceAll(_diacritics, '')
        .replaceAll('\u0640', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return readable.split(' ').take(wordCount).join(' ');
  }
}
