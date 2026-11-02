import 'package:ayyam/core/settings/app_preferences.dart';
import 'package:ayyam/core/settings/app_preferences_controller.dart';
import 'package:ayyam/core/settings/app_preferences_repository.dart';
import 'package:ayyam/features/dua/application/today_dua_controller.dart';
import 'package:ayyam/features/dua/data/dua_repository.dart';
import 'package:ayyam/features/dua/domain/dua.dart';
import 'package:ayyam/main.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows a sourced dua and marks it as recited', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final dua = _sampleDua();
    final duaRepository = MemoryDuaRepository(<Dua>[dua]);
    final preferences = AppPreferences(
      onboardingComplete: true,
      duaEnabled: true,
      lifeInDotsEnabled: false,
      reminderHour: 6,
      reminderMinute: 0,
      translationLanguage: 'English',
      dateOfBirth: null,
      missedPrayerYears: 0,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesRepositoryProvider.overrideWithValue(
            MemoryAppPreferencesRepository(preferences),
          ),
          currentDateProvider.overrideWithValue(DateTime(2026, 11, 2)),
          duaRepositoryProvider.overrideWithValue(duaRepository),
        ],
        child: const MainApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('A prayer for\ntoday.'), findsOneWidget);
    expect(find.text(dua.arabic), findsOneWidget);
    expect(find.text(dua.translation), findsOneWidget);
    expect(find.text('Quran'), findsOneWidget);
    expect(find.text('2:201'), findsOneWidget);

    await tester.ensureVisible(find.text('Mark as recited'));
    await tester.tap(find.text('Mark as recited'));
    await tester.pumpAndSettle();

    expect(find.text('Recited today'), findsOneWidget);
    expect(duaRepository.values.single.status, DuaStatus.recited);
    expect(duaRepository.values.single.recitedAt, isNotNull);

    await tester.ensureVisible(find.text('REPORT AN ISSUE'));
    await tester.tap(find.text('REPORT AN ISSUE'));
    await tester.pumpAndSettle();

    expect(find.text('Hidden for\nreview.'), findsOneWidget);
    expect(duaRepository.values.single.flagged, isTrue);
  });
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
  generatedAt: DateTime(2026, 11, 2, 6),
);
