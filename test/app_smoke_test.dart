import 'package:ayyam/core/settings/app_preferences_controller.dart';
import 'package:ayyam/core/settings/app_preferences_repository.dart';
import 'package:ayyam/core/security/api_key_vault.dart';
import 'package:ayyam/main.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('starts the Ayyam application', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesRepositoryProvider.overrideWithValue(
            MemoryAppPreferencesRepository(),
          ),
          apiKeyVaultProvider.overrideWithValue(_MemoryApiKeyVault()),
        ],
        child: const MainApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Make each\nday count.'), findsOneWidget);
    expect(find.text('Begin'), findsOneWidget);
  });

  testWidgets('welcome screen meets automated accessibility guidelines', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();

    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appPreferencesRepositoryProvider.overrideWithValue(
              MemoryAppPreferencesRepository(),
            ),
            apiKeyVaultProvider.overrideWithValue(_MemoryApiKeyVault()),
          ],
          child: const MainApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester, meetsGuideline(androidTapTargetGuideline));
      expect(tester, meetsGuideline(labeledTapTargetGuideline));
      expect(tester, meetsGuideline(textContrastGuideline));
    } finally {
      semantics.dispose();
    }
  });
}

class _MemoryApiKeyVault extends ApiKeyVault {
  @override
  Future<String?> read() async => null;

  @override
  Future<void> write(String value) async {}

  @override
  Future<void> delete() async {}
}
