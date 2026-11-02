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
}

Future<void> _pumpApp(
  WidgetTester tester,
  MemoryAppPreferencesRepository repository,
  _MemoryApiKeyVault vault,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appPreferencesRepositoryProvider.overrideWithValue(repository),
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
