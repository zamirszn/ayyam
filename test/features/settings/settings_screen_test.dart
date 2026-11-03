import 'package:ayyam/core/database/app_database.dart';
import 'package:ayyam/core/database/app_database_provider.dart';
import 'package:ayyam/core/gemini/gemini_key_validator.dart';
import 'package:ayyam/core/security/api_key_vault.dart';
import 'package:ayyam/core/settings/app_preferences.dart';
import 'package:ayyam/core/settings/app_preferences_controller.dart';
import 'package:ayyam/core/settings/app_preferences_repository.dart';
import 'package:ayyam/design/components/nocturne_switch.dart';
import 'package:ayyam/features/dua/application/today_dua_controller.dart';
import 'package:ayyam/features/dua/data/dua_repository.dart';
import 'package:ayyam/features/dua/domain/dua.dart';
import 'package:ayyam/main.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('edits and persists settings from Today', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final initial = AppPreferences(
      onboardingComplete: true,
      duaEnabled: true,
      lifeInDotsEnabled: true,
      reminderHour: 6,
      reminderMinute: 0,
      translationLanguage: 'English',
      dateOfBirth: DateTime(1990, 12, 31),
      missedPrayerYears: 2,
    );
    final repository = MemoryAppPreferencesRepository(initial);
    final vault = _MemoryApiKeyVault('old-key');
    await _pumpApp(tester, repository, vault);

    await tester.tap(find.bySemanticsLabel('Open settings'));
    await tester.pumpAndSettle();

    expect(find.text('Keep it\nyours.'), findsOneWidget);
    expect(find.text('31 / 12 / 1990'), findsOneWidget);

    await tester.tap(find.byType(NocturneSwitch).at(1));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('6:00 AM'));
    await tester.tap(find.text('6:00 AM'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PM'));
    await tester.tap(find.text('Set time'));
    await tester.pumpAndSettle();
    expect(find.text('6:00 PM'), findsOneWidget);

    await tester.ensureVisible(find.text('French'));
    await tester.tap(find.text('French'));
    await tester.pump();

    final keyField = find.byType(EditableText).first;
    await tester.ensureVisible(keyField);
    await tester.enterText(keyField, 'new-key');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Test key'));
    await tester.tap(find.text('Test key'));
    await tester.pumpAndSettle();
    expect(find.text('KEY ACCEPTED'), findsOneWidget);

    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(repository.value.lifeInDotsEnabled, isFalse);
    expect(repository.value.reminderHour, 18);
    expect(repository.value.reminderMinute, 0);
    expect(repository.value.translationLanguage, 'French');
    expect(repository.value.dateOfBirth, DateTime(1990, 12, 31));
    expect(vault.value, 'new-key');
    expect(find.text('Saved on this device.'), findsOneWidget);
  });

  testWidgets('keeps at least one feature enabled', (tester) async {
    final initial = AppPreferences(
      onboardingComplete: true,
      duaEnabled: true,
      lifeInDotsEnabled: false,
      reminderHour: 6,
      reminderMinute: 0,
      translationLanguage: 'English',
      dateOfBirth: null,
      missedPrayerYears: 0,
    );
    final repository = MemoryAppPreferencesRepository(initial);
    await _pumpApp(tester, repository, _MemoryApiKeyVault('key'));

    await tester.tap(find.bySemanticsLabel('Open settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(NocturneSwitch).first);
    await tester.pumpAndSettle();

    expect(find.text('Keep at least one feature on.'), findsOneWidget);
    expect(find.byType(NocturneSwitch).first, findsOneWidget);
    expect(repository.value.duaEnabled, isTrue);
  });

  testWidgets('enables a private daily Life check-in reminder', (tester) async {
    final initial = AppPreferences.defaults.copyWith(
      onboardingComplete: true,
      duaEnabled: false,
      lifeInDotsEnabled: true,
      dateOfBirth: DateTime(1990, 1, 1),
    );
    final repository = MemoryAppPreferencesRepository(initial);
    await _pumpApp(tester, repository, _MemoryApiKeyVault(null));

    await tester.tap(find.bySemanticsLabel('Open settings'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Daily prayer check-in'));
    await tester.tap(find.text('Daily prayer check-in'));
    await tester.pumpAndSettle();

    expect(find.text('8:00 PM'), findsOneWidget);
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(repository.value.lifeReminderEnabled, isTrue);
    expect(repository.value.lifeReminderHour, 20);
    expect(repository.value.lifeReminderMinute, 0);
  });

  testWidgets('requires a second tap before replacing data from a backup', (
    tester,
  ) async {
    final initial = AppPreferences(
      onboardingComplete: true,
      duaEnabled: true,
      lifeInDotsEnabled: false,
      reminderHour: 6,
      reminderMinute: 0,
      translationLanguage: 'English',
      dateOfBirth: null,
      missedPrayerYears: 0,
    );
    await _pumpApp(
      tester,
      MemoryAppPreferencesRepository(initial),
      _MemoryApiKeyVault('secret-key'),
    );

    await tester.tap(find.bySemanticsLabel('Open settings'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Restore JSON from clipboard'));
    expect(find.text('Copy backup JSON'), findsOneWidget);
    await tester.tap(find.text('Restore JSON from clipboard'));
    await tester.pump();

    expect(find.text('Tap again to replace local data'), findsOneWidget);
    expect(
      find.text(
        'This replaces current saved data. Invalid backups make no changes.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'deletes credentials and returns to onboarding after confirmation',
    (tester) async {
      final database = AppDatabase(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = MemoryAppPreferencesRepository(
        AppPreferences.defaults.copyWith(
          onboardingComplete: true,
          duaEnabled: true,
          lifeInDotsEnabled: false,
        ),
      );
      final vault = _MemoryApiKeyVault('secret-key');
      await _pumpApp(tester, repository, vault, database: database);

      await tester.tap(find.bySemanticsLabel('Open settings'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Delete all data'));
      await tester.tap(find.text('Delete all data'));
      await tester.pump();
      expect(find.text('Tap again to delete everything'), findsOneWidget);

      await tester.tap(find.text('Tap again to delete everything'));
      await tester.pumpAndSettle();

      expect(vault.value, isNull);
      expect(repository.value.onboardingComplete, isFalse);
      expect(find.text('Make each\nday count.'), findsOneWidget);
    },
  );
}

Future<void> _pumpApp(
  WidgetTester tester,
  MemoryAppPreferencesRepository repository,
  _MemoryApiKeyVault vault, {
  AppDatabase? database,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appPreferencesRepositoryProvider.overrideWithValue(repository),
        if (database != null) appDatabaseProvider.overrideWithValue(database),
        apiKeyVaultProvider.overrideWithValue(vault),
        currentDateProvider.overrideWithValue(DateTime(2026, 11, 2)),
        duaRepositoryProvider.overrideWithValue(
          MemoryDuaRepository(<Dua>[_sampleDua()]),
        ),
        geminiKeyValidatorProvider.overrideWithValue(
          _AcceptingGeminiKeyValidator(),
        ),
      ],
      child: const MainApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Dua _sampleDua() => Dua(
  id: 'sample-dua',
  arabic: 'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ',
  transliteration: 'Rabbana atina fid-dunya hasanatan wa fil-akhirati hasanatan wa qina adhaban-nar.',
  translation: 'Our Lord, give us good in this world and good in the Hereafter, and protect us from the torment of the Fire.',
  benefits: 'A Quranic supplication asking for good in both lives.',
  occasion: 'General',
  sources: const <DuaSource>[
    DuaSource(
      type: DuaSourceType.quran,
      collection: 'Quran',
      reference: '2:201',
      grading: 'Quran',
    ),
  ],
  assignedDate: DateTime(2026, 11, 2),
  status: DuaStatus.shown,
  generatedAt: DateTime(2026, 11, 2),
);

class _MemoryApiKeyVault extends ApiKeyVault {
  _MemoryApiKeyVault(this.value);

  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async {
    this.value = value.trim();
  }

  @override
  Future<void> delete() async {
    value = null;
  }
}

class _AcceptingGeminiKeyValidator extends GeminiKeyValidator {
  @override
  Future<GeminiKeyStatus> validate(String apiKey) async {
    return apiKey.trim().isEmpty
        ? GeminiKeyStatus.invalid
        : GeminiKeyStatus.valid;
  }
}
