import 'package:flutter/foundation.dart';

enum DuaStatus { scheduled, shown, recited }

enum DuaSourceType { quran, hadith }

@immutable
class DuaSource {
  const DuaSource({
    required this.type,
    required this.collection,
    required this.reference,
    this.grading,
  });

  final DuaSourceType type;
  final String collection;
  final String reference;
  final String? grading;

  String get displayLabel {
    final base = '$collection $reference'.trim();
    return grading == null || grading!.trim().isEmpty
        ? base
        : '$base · ${grading!.trim()}';
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'type': type.name,
    'collection': collection,
    'reference': reference,
    'grading': grading,
  };

  factory DuaSource.fromJson(Map<String, Object?> json) {
    final typeName = _requiredString(json, 'type').toLowerCase();
    final type = switch (typeName) {
      'quran' => DuaSourceType.quran,
      'hadith' => DuaSourceType.hadith,
      _ => throw FormatException('Unsupported source type: $typeName'),
    };
    return DuaSource(
      type: type,
      collection: _requiredString(json, 'collection'),
      reference: _requiredString(json, 'reference'),
      grading: _optionalString(json, 'grading'),
    );
  }
}

@immutable
class GeneratedDuaCandidate {
  const GeneratedDuaCandidate({
    required this.arabic,
    required this.transliteration,
    required this.translation,
    required this.benefits,
    required this.occasion,
    required this.sources,
  });

  final String arabic;
  final String transliteration;
  final String translation;
  final String benefits;
  final String? occasion;
  final List<DuaSource> sources;

  factory GeneratedDuaCandidate.fromJson(Map<String, Object?> json) {
    final rawSources = json['sources'];
    if (rawSources is! List<Object?>) {
      throw const FormatException('Sources must be a JSON array.');
    }
    return GeneratedDuaCandidate(
      arabic: _requiredString(json, 'arabic'),
      transliteration: _requiredString(json, 'transliteration'),
      translation: _requiredString(json, 'translation'),
      benefits: _requiredString(json, 'benefits'),
      occasion: _optionalString(json, 'occasion'),
      sources: rawSources
          .map((source) {
            if (source is! Map<Object?, Object?>) {
              throw const FormatException('Each source must be a JSON object.');
            }
            return DuaSource.fromJson(
              source.map((key, value) => MapEntry(key.toString(), value)),
            );
          })
          .toList(growable: false),
    );
  }
}

@immutable
class Dua {
  const Dua({
    required this.id,
    required this.arabic,
    required this.transliteration,
    required this.translation,
    required this.benefits,
    required this.occasion,
    required this.sources,
    required this.assignedDate,
    required this.status,
    required this.generatedAt,
    this.recitedAt,
    this.flagged = false,
  });

  final String id;
  final String arabic;
  final String transliteration;
  final String translation;
  final String benefits;
  final String? occasion;
  final List<DuaSource> sources;
  final DateTime assignedDate;
  final DuaStatus status;
  final DateTime generatedAt;
  final DateTime? recitedAt;
  final bool flagged;

  bool get isRecited => status == DuaStatus.recited;

  Dua copyWith({DuaStatus? status, DateTime? recitedAt, bool? flagged}) {
    return Dua(
      id: id,
      arabic: arabic,
      transliteration: transliteration,
      translation: translation,
      benefits: benefits,
      occasion: occasion,
      sources: sources,
      assignedDate: assignedDate,
      status: status ?? this.status,
      generatedAt: generatedAt,
      recitedAt: recitedAt ?? this.recitedAt,
      flagged: flagged ?? this.flagged,
    );
  }
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key must be a non-empty string.');
  }
  return value.trim();
}

String? _optionalString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) throw FormatException('$key must be a string.');
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}
