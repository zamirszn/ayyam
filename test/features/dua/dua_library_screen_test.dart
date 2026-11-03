import 'package:ayyam/core/settings/app_preferences.dart';
import 'package:ayyam/core/settings/app_preferences_controller.dart';
import 'package:ayyam/core/settings/app_preferences_repository.dart';
import 'package:ayyam/features/dua/application/dua_library_service.dart';
import 'package:ayyam/features/dua/application/today_dua_controller.dart';
import 'package:ayyam/features/dua/data/dua_repository.dart';
import 'package:ayyam/features/dua/domain/dua.dart';
import 'package:ayyam/main.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('opens history, searches collection and shows source details', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = MemoryDuaRepository(<Dua>[
      _dua(
        id: 'today',
        date: DateTime(2026, 11, 3),
        translation: 'My Lord, increase me in knowledge.',
        occasion: 'Learning',
        recitedAt: DateTime(2026, 11, 3, 7),
      ),
      _dua(
        id: 'travel',
        date: DateTime(2026, 11, 2),
        translation: 'A prayer for safe travel.',
        occasion: 'Travel',
        recitedAt: DateTime(2026, 11, 2, 7),
        hadith: true,
      ),
      _dua(
        id: 'missed',
        date: DateTime(2026, 11, 1),
        translation: 'A prayer for forgiveness.',
        occasion: 'Forgiveness',
      ),
    ]);
    await _pumpApp(tester, repository);

    await tester.tap(find.bySemanticsLabel('Open dua library'));
    await tester.pumpAndSettle();
    expect(find.text('Keep the\nrecord.'), findsOneWidget);
    expect(find.text('HISTORY'), findsOneWidget);

    await tester.tap(find.text('COLLECTION'));
    await tester.pumpAndSettle();
    expect(find.text('A prayer for safe travel.'), findsOneWidget);

    final search = find.byType(EditableText);
    await tester.enterText(search, 'knowledge');
    await tester.pump();
    expect(find.text('My Lord, increase me in knowledge.'), findsOneWidget);
    expect(find.text('A prayer for safe travel.'), findsNothing);

    await tester.ensureVisible(find.text('My Lord, increase me in knowledge.'));
    await tester.tap(find.text('My Lord, increase me in knowledge.'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('20:114'));
    await tester.tap(find.text('20:114'));
    await tester.pumpAndSettle();

    expect(find.text('Follow the\nreference.'), findsOneWidget);
    expect(find.text('20:114'), findsOneWidget);
    expect(find.text('Quran'), findsWidgets);
  });

  testWidgets('adds a missed dua later without changing its assigned day', (
    tester,
  ) async {
    final repository = MemoryDuaRepository(<Dua>[
      _dua(
        id: 'today',
        date: DateTime(2026, 11, 3),
        translation: 'Today prayer.',
      ),
      _dua(
        id: 'missed',
        date: DateTime(2026, 11, 1),
        translation: 'A missed prayer.',
        occasion: 'Forgiveness',
      ),
    ]);
    await _pumpApp(tester, repository);

    await tester.tap(find.bySemanticsLabel('Open dua library'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('A missed prayer.'));
    await tester.tap(find.text('A missed prayer.'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Recite and add to collection'));
    await tester.tap(find.text('Recite and add to collection'));
    await tester.pumpAndSettle();

    final updated = await repository.findAssignedTo(DateTime(2026, 11, 1));
    expect(updated?.isRecited, isTrue);
    expect(updated?.assignedDate, DateTime(2026, 11, 1));
    expect(updated?.recitedAt, isNotNull);
  });
}

Future<void> _pumpApp(
  WidgetTester tester,
  MemoryDuaRepository repository,
) async {
  final preferences = AppPreferences.defaults.copyWith(
    onboardingComplete: true,
    duaEnabled: true,
    lifeInDotsEnabled: false,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appPreferencesRepositoryProvider.overrideWithValue(
          MemoryAppPreferencesRepository(preferences),
        ),
        currentDateProvider.overrideWithValue(DateTime(2026, 11, 3)),
        duaLibraryTodayProvider.overrideWithValue(DateTime(2026, 11, 3)),
        duaRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MainApp(),
    ),
  );
  await tester.pumpAndSettle();
}

Dua _dua({
  required String id,
  required DateTime date,
  required String translation,
  String occasion = 'General',
  DateTime? recitedAt,
  bool hadith = false,
}) {
  return Dua(
    id: id,
    arabic: 'رَبِّ زِدْنِي عِلْمًا',
    transliteration: 'Rabbi zidni ilma.',
    translation: translation,
    benefits: 'A sourced context for this supplication.',
    occasion: occasion,
    sources: <DuaSource>[
      if (hadith)
        const DuaSource(
          type: DuaSourceType.hadith,
          collection: 'Sahih Muslim',
          reference: '1342',
          grading: 'Sahih',
        )
      else
        const DuaSource(
          type: DuaSourceType.quran,
          collection: 'Quran',
          reference: '20:114',
          grading: 'Quran',
        ),
    ],
    assignedDate: date,
    status: recitedAt == null ? DuaStatus.shown : DuaStatus.recited,
    generatedAt: date,
    recitedAt: recitedAt,
  );
}
