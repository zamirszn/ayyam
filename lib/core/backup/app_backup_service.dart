import 'dart:convert';

import 'package:ayyam/core/database/app_database.dart';
import 'package:ayyam/core/database/app_database_provider.dart';
import 'package:ayyam/core/settings/app_preferences.dart';
import 'package:ayyam/core/settings/app_preferences_controller.dart';
import 'package:ayyam/core/settings/app_preferences_repository.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appBackupServiceProvider = Provider<AppBackupService>((ref) {
  return AppBackupService(
    ref.watch(appDatabaseProvider),
    ref.watch(appPreferencesRepositoryProvider),
  );
});

@immutable
class AppBackupSummary {
  const AppBackupSummary({
    required this.preferences,
    required this.duas,
    required this.prayerDays,
    required this.makeupDebts,
  });

  final AppPreferences preferences;
  final int duas;
  final int prayerDays;
  final int makeupDebts;
}

class AppBackupService {
  AppBackupService(
    this._database,
    this._preferencesRepository, {
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  static const String format = 'ayyam-backup';
  static const int version = 1;

  final AppDatabase _database;
  final AppPreferencesRepository _preferencesRepository;
  final DateTime Function() _now;

  Future<String> exportJson() async {
    final preferences = await _preferencesRepository.load();
    final results = await Future.wait<List<Object?>>(<Future<List<Object?>>>[
      _database.select(_database.duaRecords).get(),
      _database.select(_database.prayerDayRecords).get(),
      _database.select(_database.makeupDebtRecords).get(),
      _database.select(_database.lifeMetadataRecords).get(),
    ]);
    final duas = results[0].cast<DuaRecord>();
    final prayerDays = results[1].cast<PrayerDayRecord>();
    final makeupDebts = results[2].cast<MakeupDebtRecord>();
    final metadata = results[3].cast<LifeMetadataRecord>();

    final backup = <String, Object?>{
      'format': format,
      'version': version,
      'exportedAt': _now().toUtc().toIso8601String(),
      'preferences': _preferencesToJson(preferences),
      'duas': <Object?>[
        for (final record in duas)
          <String, Object?>{
            'id': record.id,
            'arabic': record.arabic,
            'transliteration': record.transliteration,
            'translation': record.translation,
            'benefits': record.benefits,
            'occasion': record.occasion,
            'sources': jsonDecode(record.sourcesJson),
            'assignedDay': record.assignedDay,
            'status': record.status,
            'generatedAt': record.generatedAt.toUtc().toIso8601String(),
            'recitedAt': record.recitedAt?.toUtc().toIso8601String(),
            'flagged': record.flagged,
          },
      ],
      'prayerDays': <Object?>[
        for (final record in prayerDays)
          <String, Object?>{
            'day': record.day,
            'status': record.status,
            'estimated': record.estimated,
            'recordedAt': record.recordedAt.toUtc().toIso8601String(),
          },
      ],
      'makeupDebts': <Object?>[
        for (final record in makeupDebts)
          <String, Object?>{
            'id': record.id,
            'sourceDay': record.sourceDay,
            'origin': record.origin,
            'completedSteps': record.completedSteps,
            'createdAt': record.createdAt.toUtc().toIso8601String(),
            'repaidAt': record.repaidAt?.toUtc().toIso8601String(),
          },
      ],
      'lifeMetadata': <Object?>[
        for (final record in metadata)
          <String, Object?>{'key': record.key, 'value': record.value},
      ],
    };
    return const JsonEncoder.withIndent('  ').convert(backup);
  }

  Future<AppBackupSummary> importJson(String source) async {
    final parsed = _ParsedBackup.parse(source);
    final previousPreferences = await _preferencesRepository.load();
    await _preferencesRepository.save(parsed.preferences);
    try {
      await _database.transaction(() async {
        await _database.delete(_database.duaRecords).go();
        await _database.delete(_database.prayerDayRecords).go();
        await _database.delete(_database.makeupDebtRecords).go();
        await _database.delete(_database.lifeMetadataRecords).go();
        await _database.batch((batch) {
          if (parsed.duas.isNotEmpty) {
            batch.insertAll(_database.duaRecords, parsed.duas);
          }
          if (parsed.prayerDays.isNotEmpty) {
            batch.insertAll(_database.prayerDayRecords, parsed.prayerDays);
          }
          if (parsed.makeupDebts.isNotEmpty) {
            batch.insertAll(_database.makeupDebtRecords, parsed.makeupDebts);
          }
          if (parsed.lifeMetadata.isNotEmpty) {
            batch.insertAll(_database.lifeMetadataRecords, parsed.lifeMetadata);
          }
        });
      });
    } catch (_) {
      await _preferencesRepository.save(previousPreferences);
      rethrow;
    }
    return AppBackupSummary(
      preferences: parsed.preferences,
      duas: parsed.duas.length,
      prayerDays: parsed.prayerDays.length,
      makeupDebts: parsed.makeupDebts.length,
    );
  }

  Future<void> deleteAllData() async {
    final previousPreferences = await _preferencesRepository.load();
    await _preferencesRepository.save(AppPreferences.defaults);
    try {
      await _database.transaction(() async {
        await _database.delete(_database.duaRecords).go();
        await _database.delete(_database.prayerDayRecords).go();
        await _database.delete(_database.makeupDebtRecords).go();
        await _database.delete(_database.lifeMetadataRecords).go();
      });
    } catch (_) {
      await _preferencesRepository.save(previousPreferences);
      rethrow;
    }
  }
}

class _ParsedBackup {
  const _ParsedBackup({
    required this.preferences,
    required this.duas,
    required this.prayerDays,
    required this.makeupDebts,
    required this.lifeMetadata,
  });

  final AppPreferences preferences;
  final List<DuaRecordsCompanion> duas;
  final List<PrayerDayRecordsCompanion> prayerDays;
  final List<MakeupDebtRecordsCompanion> makeupDebts;
  final List<LifeMetadataRecordsCompanion> lifeMetadata;

  factory _ParsedBackup.parse(String source) {
    final decoded = jsonDecode(source);
    final root = _map(decoded, 'Backup');
    if (_string(root, 'format') != AppBackupService.format) {
      throw const FormatException('This is not an Ayyam backup.');
    }
    if (_integer(root, 'version') != AppBackupService.version) {
      throw const FormatException('This backup version is not supported.');
    }
    final preferences = _preferencesFromJson(
      _map(root['preferences'], 'preferences'),
    );
    final rawDuas = _list(root, 'duas');
    final rawPrayerDays = _list(root, 'prayerDays');
    final rawDebts = _list(root, 'makeupDebts');
    final rawMetadata = _list(root, 'lifeMetadata');

    final duaIds = <String>{};
    final assignedDays = <String>{};
    final duas = <DuaRecordsCompanion>[
      for (var index = 0; index < rawDuas.length; index++)
        _dua(
          _map(rawDuas[index], 'duas[$index]'),
          duaIds: duaIds,
          assignedDays: assignedDays,
        ),
    ];
    final prayerKeys = <String>{};
    final prayerDays = <PrayerDayRecordsCompanion>[
      for (var index = 0; index < rawPrayerDays.length; index++)
        _prayerDay(
          _map(rawPrayerDays[index], 'prayerDays[$index]'),
          keys: prayerKeys,
        ),
    ];
    final debtIds = <int>{};
    final debtSourceDays = <String>{};
    final debts = <MakeupDebtRecordsCompanion>[
      for (var index = 0; index < rawDebts.length; index++)
        _makeupDebt(
          _map(rawDebts[index], 'makeupDebts[$index]'),
          ids: debtIds,
          sourceDays: debtSourceDays,
        ),
    ];
    final metadataKeys = <String>{};
    final metadata = <LifeMetadataRecordsCompanion>[
      for (var index = 0; index < rawMetadata.length; index++)
        _metadata(
          _map(rawMetadata[index], 'lifeMetadata[$index]'),
          keys: metadataKeys,
        ),
    ];
    return _ParsedBackup(
      preferences: preferences,
      duas: duas,
      prayerDays: prayerDays,
      makeupDebts: debts,
      lifeMetadata: metadata,
    );
  }
}

Map<String, Object?> _preferencesToJson(
  AppPreferences value,
) => <String, Object?>{
  'onboardingComplete': value.onboardingComplete,
  'duaEnabled': value.duaEnabled,
  'lifeInDotsEnabled': value.lifeInDotsEnabled,
  'reminderHour': value.reminderHour,
  'reminderMinute': value.reminderMinute,
  'translationLanguage': value.translationLanguage,
  'dateOfBirth': value.dateOfBirth == null ? null : _day(value.dateOfBirth!),
  'missedPrayerYears': value.missedPrayerYears,
  'lifeReminderEnabled': value.lifeReminderEnabled,
  'lifeReminderHour': value.lifeReminderHour,
  'lifeReminderMinute': value.lifeReminderMinute,
};

AppPreferences _preferencesFromJson(Map<String, Object?> json) {
  final duaEnabled = _boolean(json, 'duaEnabled');
  final lifeEnabled = _boolean(json, 'lifeInDotsEnabled');
  if (!duaEnabled && !lifeEnabled) {
    throw const FormatException('At least one feature must be enabled.');
  }
  final hour = _integer(json, 'reminderHour');
  final minute = _integer(json, 'reminderMinute');
  final missedYears = _integer(json, 'missedPrayerYears');
  final lifeReminderEnabled = _booleanOrDefault(
    json,
    'lifeReminderEnabled',
    AppPreferences.defaults.lifeReminderEnabled,
  );
  final lifeReminderHour = _integerOrDefault(
    json,
    'lifeReminderHour',
    AppPreferences.defaults.lifeReminderHour,
  );
  final lifeReminderMinute = _integerOrDefault(
    json,
    'lifeReminderMinute',
    AppPreferences.defaults.lifeReminderMinute,
  );
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
    throw const FormatException('Reminder time is invalid.');
  }
  if (missedYears < 0) {
    throw const FormatException('Missed prayer years cannot be negative.');
  }
  if (lifeReminderHour < 0 ||
      lifeReminderHour > 23 ||
      lifeReminderMinute < 0 ||
      lifeReminderMinute > 59) {
    throw const FormatException('Life reminder time is invalid.');
  }
  final rawBirth = json['dateOfBirth'];
  return AppPreferences(
    onboardingComplete: _boolean(json, 'onboardingComplete'),
    duaEnabled: duaEnabled,
    lifeInDotsEnabled: lifeEnabled,
    reminderHour: hour,
    reminderMinute: minute,
    translationLanguage: _string(json, 'translationLanguage'),
    dateOfBirth: rawBirth == null
        ? null
        : _parseDay(_valueString(rawBirth, 'dateOfBirth')),
    missedPrayerYears: missedYears,
    lifeReminderEnabled: lifeReminderEnabled,
    lifeReminderHour: lifeReminderHour,
    lifeReminderMinute: lifeReminderMinute,
  );
}

DuaRecordsCompanion _dua(
  Map<String, Object?> json, {
  required Set<String> duaIds,
  required Set<String> assignedDays,
}) {
  final id = _string(json, 'id');
  final assignedDay = _validDay(json, 'assignedDay');
  if (!duaIds.add(id)) throw FormatException('Duplicate dua id: $id');
  if (!assignedDays.add(assignedDay)) {
    throw FormatException('Duplicate assigned dua day: $assignedDay');
  }
  final status = _string(json, 'status');
  if (!const <String>{'scheduled', 'shown', 'recited'}.contains(status)) {
    throw FormatException('Unsupported dua status: $status');
  }
  final sources = json['sources'];
  if (sources is! List<Object?>) {
    throw const FormatException('Dua sources must be an array.');
  }
  if (sources.isEmpty) {
    throw const FormatException('Each dua must include at least one source.');
  }
  for (final source in sources) {
    final sourceJson = _map(source, 'dua source');
    final type = _string(sourceJson, 'type');
    if (!const <String>{'quran', 'hadith'}.contains(type)) {
      throw FormatException('Unsupported dua source type: $type');
    }
    _string(sourceJson, 'collection');
    _string(sourceJson, 'reference');
    _optionalString(sourceJson, 'grading');
  }
  return DuaRecordsCompanion.insert(
    id: id,
    arabic: _string(json, 'arabic'),
    transliteration: _string(json, 'transliteration'),
    translation: _string(json, 'translation'),
    benefits: _string(json, 'benefits'),
    occasion: Value(_optionalString(json, 'occasion')),
    sourcesJson: jsonEncode(sources),
    assignedDay: assignedDay,
    status: status,
    generatedAt: _dateTime(json, 'generatedAt'),
    recitedAt: Value(_optionalDateTime(json, 'recitedAt')),
    flagged: Value(_boolean(json, 'flagged')),
  );
}

PrayerDayRecordsCompanion _prayerDay(
  Map<String, Object?> json, {
  required Set<String> keys,
}) {
  final day = _validDay(json, 'day');
  if (!keys.add(day)) throw FormatException('Duplicate prayer day: $day');
  final status = _string(json, 'status');
  if (!const <String>{'completed', 'missed'}.contains(status)) {
    throw FormatException('Unsupported prayer status: $status');
  }
  return PrayerDayRecordsCompanion.insert(
    day: day,
    status: status,
    estimated: Value(_boolean(json, 'estimated')),
    recordedAt: _dateTime(json, 'recordedAt'),
  );
}

MakeupDebtRecordsCompanion _makeupDebt(
  Map<String, Object?> json, {
  required Set<int> ids,
  required Set<String> sourceDays,
}) {
  final id = _integer(json, 'id');
  if (id <= 0 || !ids.add(id)) {
    throw FormatException('Invalid or duplicate make-up id: $id');
  }
  final origin = _string(json, 'origin');
  if (!const <String>{'missedDay', 'estimatedPast'}.contains(origin)) {
    throw FormatException('Unsupported make-up origin: $origin');
  }
  final rawSourceDay = json['sourceDay'];
  final sourceDay = rawSourceDay == null
      ? null
      : _parseDay(_valueString(rawSourceDay, 'sourceDay'));
  final sourceKey = sourceDay == null ? null : _day(sourceDay);
  if (sourceKey != null && !sourceDays.add(sourceKey)) {
    throw FormatException('Duplicate make-up source day: $sourceKey');
  }
  final steps = _integer(json, 'completedSteps');
  if (steps < 0 || steps > 5) {
    throw const FormatException('Make-up steps must be between 0 and 5.');
  }
  return MakeupDebtRecordsCompanion.insert(
    id: Value(id),
    sourceDay: Value(sourceKey),
    origin: origin,
    completedSteps: Value(steps),
    createdAt: _dateTime(json, 'createdAt'),
    repaidAt: Value(_optionalDateTime(json, 'repaidAt')),
  );
}

LifeMetadataRecordsCompanion _metadata(
  Map<String, Object?> json, {
  required Set<String> keys,
}) {
  final key = _string(json, 'key');
  if (!keys.add(key)) throw FormatException('Duplicate metadata key: $key');
  return LifeMetadataRecordsCompanion.insert(
    key: key,
    value: _string(json, 'value', allowEmpty: true),
  );
}

Map<String, Object?> _map(Object? value, String label) {
  if (value is! Map<Object?, Object?>) {
    throw FormatException('$label must be a JSON object.');
  }
  return value.map((key, value) => MapEntry(key.toString(), value));
}

List<Object?> _list(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! List<Object?>) {
    throw FormatException('$key must be a JSON array.');
  }
  return value;
}

String _string(
  Map<String, Object?> json,
  String key, {
  bool allowEmpty = false,
}) {
  final value = json[key];
  if (value is! String || (!allowEmpty && value.trim().isEmpty)) {
    throw FormatException('$key must be a string.');
  }
  return allowEmpty ? value : value.trim();
}

String _valueString(Object? value, String key) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key must be a string.');
  }
  return value.trim();
}

String? _optionalString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) throw FormatException('$key must be a string.');
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

int _integer(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int) throw FormatException('$key must be an integer.');
  return value;
}

int _integerOrDefault(Map<String, Object?> json, String key, int fallback) {
  if (!json.containsKey(key)) return fallback;
  return _integer(json, key);
}

bool _boolean(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! bool) throw FormatException('$key must be true or false.');
  return value;
}

bool _booleanOrDefault(Map<String, Object?> json, String key, bool fallback) {
  if (!json.containsKey(key)) return fallback;
  return _boolean(json, key);
}

DateTime _dateTime(Map<String, Object?> json, String key) {
  final value = _string(json, key);
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw FormatException('$key is not a valid date.');
  return parsed;
}

DateTime? _optionalDateTime(Map<String, Object?> json, String key) {
  if (json[key] == null) return null;
  return _dateTime(json, key);
}

String _validDay(Map<String, Object?> json, String key) =>
    _day(_parseDay(_string(json, key)));

DateTime _parseDay(String value) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) throw FormatException('Invalid day: $value');
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final parsed = DateTime(year, month, day);
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    throw FormatException('Invalid day: $value');
  }
  return parsed;
}

String _day(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
