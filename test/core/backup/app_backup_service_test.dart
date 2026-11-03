import 'dart:convert';

import 'package:ayyam/core/backup/app_backup_service.dart';
import 'package:ayyam/core/database/app_database.dart';
import 'package:ayyam/core/settings/app_preferences.dart';
import 'package:ayyam/core/settings/app_preferences_repository.dart';
import 'package:ayyam/features/dua/data/dua_repository.dart';
import 'package:ayyam/features/dua/domain/dua.dart';
import 'package:ayyam/features/life/data/life_repository.dart';
import 'package:ayyam/features/life/domain/prayer_day.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exports and restores all local data without credentials', () async {
    final sourceDatabase = AppDatabase(NativeDatabase.memory());
    final sourcePreferences = MemoryAppPreferencesRepository(_preferences());
    final sourceDuas = DriftDuaRepository(sourceDatabase);
    final sourceLife = DriftLifeRepository(sourceDatabase);
    await sourceDuas.save(_dua('kept-dua', DateTime(2026, 11, 2)));
    await sourceLife.recordDay(
      day: DateTime(2026, 11, 2),
      status: PrayerDayStatus.missed,
      recordedAt: DateTime(2026, 11, 2, 22),
    );
    final datedDebt = (await sourceLife.allDebts()).single;
    await sourceLife.addDebtStep(datedDebt.id, DateTime(2026, 11, 3));
    await sourceLife.syncEstimatedDebtTarget(1, DateTime(2026, 11, 3));

    final exported = await AppBackupService(
      sourceDatabase,
      sourcePreferences,
      now: () => DateTime.utc(2026, 11, 3, 12),
    ).exportJson();
    await sourceDatabase.close();

    expect(exported, contains('"format": "ayyam-backup"'));
    expect(exported, isNot(contains('secret-key')));
    final targetDatabase = AppDatabase(NativeDatabase.memory());
    addTearDown(targetDatabase.close);
    final targetPreferences = MemoryAppPreferencesRepository(
      AppPreferences.defaults,
    );
    final summary = await AppBackupService(
      targetDatabase,
      targetPreferences,
    ).importJson(exported);

    expect(summary.duas, 1);
    expect(summary.prayerDays, 1);
    expect(summary.makeupDebts, 2);
    expect(targetPreferences.value.translationLanguage, 'French');
    expect(targetPreferences.value.dateOfBirth, DateTime(1995, 4, 12));
    expect(targetPreferences.value.lifeReminderEnabled, isTrue);
    expect(targetPreferences.value.lifeReminderHour, 21);
    expect(targetPreferences.value.lifeReminderMinute, 30);
    expect(
      (await DriftDuaRepository(targetDatabase).all()).single.id,
      'kept-dua',
    );
    final restoredLife = DriftLifeRepository(targetDatabase);
    expect(
      (await restoredLife.allPrayerDays()).single.status,
      PrayerDayStatus.missed,
    );
    final debts = await restoredLife.allDebts();
    expect(debts, hasLength(2));
    expect(
      debts.singleWhere((debt) => debt.sourceDay != null).completedSteps,
      1,
    );

    await restoredLife.syncEstimatedDebtTarget(1, DateTime(2026, 11, 4));
    expect(await restoredLife.allDebts(), hasLength(2));
  });

  test('rejects an invalid backup before changing local data', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final preferences = MemoryAppPreferencesRepository(_preferences());
    final duas = DriftDuaRepository(database);
    await duas.save(_dua('existing', DateTime(2026, 11, 1)));
    final service = AppBackupService(database, preferences);
    final decoded =
        jsonDecode(await service.exportJson()) as Map<String, Object?>;
    final rawDuas = decoded['duas']! as List<Object?>;
    final firstDua = rawDuas.single! as Map<String, Object?>;
    firstDua['assignedDay'] = '2026-02-30';

    await expectLater(
      service.importJson(jsonEncode(decoded)),
      throwsA(isA<FormatException>()),
    );

    expect((await duas.all()).single.id, 'existing');
    expect(preferences.value.translationLanguage, 'French');
  });

  test('deletes every stored table and resets preferences', () async {
    final database = AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    final preferences = MemoryAppPreferencesRepository(_preferences());
    await DriftDuaRepository(database)
        .save(_dua('to-delete', DateTime(2026, 11, 1)));
    final life = DriftLifeRepository(database);
    await life.recordDay(
      day: DateTime(2026, 11, 1),
      status: PrayerDayStatus.missed,
      recordedAt: DateTime(2026, 11, 1, 22),
    );
    await life.syncEstimatedDebtTarget(2, DateTime(2026, 11, 2));

    await AppBackupService(database, preferences).deleteAllData();

    expect(await DriftDuaRepository(database).all(), isEmpty);
    expect(await life.allPrayerDays(), isEmpty);
    expect(await life.allDebts(), isEmpty);
    expect(await database.select(database.lifeMetadataRecords).get(), isEmpty);
    expect(preferences.value.onboardingComplete, isFalse);
    expect(preferences.value.dateOfBirth, isNull);
    expect(preferences.value.missedPrayerYears, 0);
  });
}

AppPreferences _preferences() => AppPreferences(
  onboardingComplete: true,
  duaEnabled: true,
  lifeInDotsEnabled: true,
  reminderHour: 7,
  reminderMinute: 15,
  translationLanguage: 'French',
  dateOfBirth: DateTime(1995, 4, 12),
  missedPrayerYears: 1,
  lifeReminderEnabled: true,
  lifeReminderHour: 21,
  lifeReminderMinute: 30,
);

Dua _dua(String id, DateTime day) => Dua(
  id: id,
  arabic: 'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً',
  transliteration: 'Rabbana atina fid-dunya hasanatan.',
  translation: 'Our Lord, give us good in this world.',
  benefits: 'A Quranic supplication.',
  occasion: 'General',
  sources: const <DuaSource>[
    DuaSource(
      type: DuaSourceType.quran,
      collection: 'Quran',
      reference: '2:201',
      grading: 'Quran',
    ),
  ],
  assignedDate: day,
  status: DuaStatus.recited,
  generatedAt: day,
  recitedAt: day.add(const Duration(hours: 20)),
  flagged: true,
);
