import 'package:ayyam/core/settings/app_preferences.dart';
import 'package:ayyam/core/settings/app_preferences_controller.dart';
import 'package:ayyam/core/settings/app_preferences_repository.dart';
import 'package:ayyam/features/dua/application/dua_reminder_platform.dart';
import 'package:ayyam/features/life/application/life_dashboard_controller.dart';
import 'package:ayyam/features/life/data/life_repository.dart';
import 'package:ayyam/features/life/domain/prayer_day.dart';
import 'package:ayyam/main.dart';
import 'package:ayyam/features/today/presentation/today_screen.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('checks in today and completes a personal make-up item', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = MemoryLifeRepository();
    await _pumpApp(tester, repository);

    await tester.tap(find.bySemanticsLabel('Open Life in Dots').first);
    await tester.pumpAndSettle();
    expect(find.text('36,500+ DAYS'), findsOneWidget);
    expect(find.text('How was today’s prayer day?'), findsOneWidget);

    await tester.ensureVisible(find.text('One or more missed'));
    await tester.tap(find.text('One or more missed'));
    await tester.pumpAndSettle();
    expect(find.text('MISSED'), findsWidgets);

    final debts = await repository.allDebts();
    expect(debts, hasLength(1));
    expect(debts.single.sourceDay, DateTime(2026, 11, 3));

    await tester.ensureVisible(find.text('1 outstanding'));
    await tester.tap(find.text('1 outstanding'));
    await tester.pumpAndSettle();
    expect(find.text('0 / 5'), findsOneWidget);

    await tester.tap(find.text('Add one step'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 5'), findsOneWidget);

    await tester.tap(find.text('Complete'));
    await tester.pumpAndSettle();
    expect(find.text('No make-up items are outstanding.'), findsOneWidget);
    expect((await repository.allDebts()).single.isRepaid, isTrue);
  });

  testWidgets('backfills an explicit past range as missed', (tester) async {
    final repository = MemoryLifeRepository();
    await _pumpApp(tester, repository);

    await tester.tap(find.bySemanticsLabel('Open Life in Dots').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Backfill a past range'));
    await tester.tap(find.text('Backfill a past range'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Missed'));
    await tester.ensureVisible(find.text('Apply range'));
    await tester.tap(find.text('Apply range'));
    await tester.pumpAndSettle();

    final days = await repository.allPrayerDays();
    expect(days, hasLength(7));
    expect(days.every((day) => day.status == PrayerDayStatus.missed), isTrue);
    expect(days.every((day) => day.estimated), isTrue);
    expect(await repository.allDebts(), hasLength(7));
  });

  testWidgets('opens local prayer analytics from the life dashboard', (
    tester,
  ) async {
    await _pumpApp(tester, MemoryLifeRepository());

    await tester.tap(find.bySemanticsLabel('Open Life in Dots').first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('View prayer patterns'));
    await tester.tap(find.text('View prayer patterns'));
    await tester.pumpAndSettle();

    expect(find.text('Patterns,\nnot pressure.'), findsOneWidget);
    expect(find.text('COMPLETION RATE'), findsOneWidget);
    expect(find.text('SIX-MONTH VIEW'), findsOneWidget);
    await tester.ensureVisible(find.text('No outstanding items'));
    expect(find.text('No outstanding items'), findsOneWidget);
  });

  testWidgets('opens Life in Dots directly from its reminder', (tester) async {
    await _pumpApp(tester, MemoryLifeRepository());
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TodayScreen)),
    );

    container.read(selectedLifeReminderProvider.notifier).select();
    await tester.pumpAndSettle();

    expect(find.text('36,500+ DAYS'), findsOneWidget);
    expect(find.text('How was today’s prayer day?'), findsOneWidget);
    expect(container.read(selectedLifeReminderProvider), isFalse);
  });
}

Future<void> _pumpApp(
  WidgetTester tester,
  MemoryLifeRepository repository,
) async {
  final preferences = AppPreferences.defaults.copyWith(
    onboardingComplete: true,
    duaEnabled: false,
    lifeInDotsEnabled: true,
    dateOfBirth: DateTime(2000, 1, 1),
    missedPrayerYears: 0,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appPreferencesRepositoryProvider.overrideWithValue(
          MemoryAppPreferencesRepository(preferences),
        ),
        lifeRepositoryProvider.overrideWithValue(repository),
        lifeNowProvider.overrideWithValue(DateTime(2026, 11, 3, 20)),
      ],
      child: const MainApp(),
    ),
  );
  await tester.pumpAndSettle();
}
