import 'package:ayyam/core/security/api_key_vault.dart';
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

  testWidgets('fits welcome and feature steps at 200 percent text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

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
    await tester.tap(find.text('DD / MM / YYYY'));
    await tester.pumpAndSettle();
    expect(find.text('DD / MM / YYYY'), findsWidgets);
    await tester.tap(find.text('Set date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Keep the\nday on time.'), findsOneWidget);
    await tester.tap(find.text('Finish setup'));
    await tester.pumpAndSettle();

    expect(find.text('A life in\ndays.'), findsOneWidget);
    expect(repository.value.onboardingComplete, isTrue);
    expect(repository.value.duaEnabled, isFalse);
    expect(repository.value.lifeInDotsEnabled, isTrue);
    expect(repository.value.dateOfBirth, isNotNull);
    expect(repository.value.dateOfBirth!.isAfter(DateTime.now()), isFalse);
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
        apiKeyVaultProvider.overrideWithValue(_MemoryApiKeyVault()),
      ],
      child: const MainApp(),
    ),
  );
  await tester.pumpAndSettle();
}

class _MemoryApiKeyVault extends ApiKeyVault {
  @override
  Future<String?> read() async => null;

  @override
  Future<void> write(String value) async {}

  @override
  Future<void> delete() async {}
}
