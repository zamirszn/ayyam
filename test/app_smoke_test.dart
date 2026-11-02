import 'package:ayyam/core/settings/app_preferences_controller.dart';
import 'package:ayyam/core/settings/app_preferences_repository.dart';
import 'package:ayyam/main.dart';
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
        ],
        child: const MainApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Make each\nday count.'), findsOneWidget);
    expect(find.text('Begin'), findsOneWidget);
  });
}
