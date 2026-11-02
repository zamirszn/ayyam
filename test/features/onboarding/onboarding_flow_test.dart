import 'package:ayyam/core/settings/app_preferences_controller.dart';
import 'package:ayyam/core/settings/app_preferences_repository.dart';
import 'package:ayyam/design/components/nocturne_switch.dart';
import 'package:ayyam/main.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('fits the welcome and feature steps on a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpApp(tester, MemoryAppPreferencesRepository());
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Begin'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('requires at least one feature', (tester) async {
    await _pumpApp(tester, MemoryAppPreferencesRepository());

    await tester.tap(find.text('Begin'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(NocturneSwitch).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(NocturneSwitch).first);
    await tester.pumpAndSettle();

    expect(find.text('Keep at least one feature on.'), findsOneWidget);
  });

  testWidgets('completes a Life in Dots only setup', (tester) async {
    final repository = MemoryAppPreferencesRepository();
    await _pumpApp(tester, repository);

    await tester.tap(find.text('Begin'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(NocturneSwitch).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Place the\nfirst dot.'), findsOneWidget);
    await tester.enterText(find.byType(EditableText).first, '1990-01-01');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Keep the\nday on time.'), findsOneWidget);
    await tester.tap(find.text('Finish setup'));
    await tester.pumpAndSettle();

    expect(find.text('The first day\nis ready.'), findsOneWidget);
    expect(repository.value.onboardingComplete, isTrue);
    expect(repository.value.duaEnabled, isFalse);
    expect(repository.value.lifeInDotsEnabled, isTrue);
    expect(repository.value.dateOfBirth, DateTime(1990));
  });
}

Future<void> _pumpApp(
  WidgetTester tester,
  MemoryAppPreferencesRepository repository,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appPreferencesRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MainApp(),
    ),
  );
  await tester.pumpAndSettle();
}
