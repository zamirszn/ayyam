import 'package:ayyam/core/settings/app_preferences.dart';
import 'package:ayyam/core/settings/app_preferences_controller.dart';
import 'package:ayyam/core/settings/app_preferences_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('completes onboarding and persists the selected setup', () async {
    final repository = MemoryAppPreferencesRepository();
    final container = ProviderContainer(
      overrides: [
        appPreferencesRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    expect(
      await container.read(appPreferencesProvider.future),
      AppPreferences.defaults,
    );

    const setup = OnboardingSetup(
      duaEnabled: true,
      lifeInDotsEnabled: false,
      reminderHour: 7,
      reminderMinute: 30,
      translationLanguage: 'French',
      dateOfBirth: null,
      missedPrayerYears: 0,
    );
    await container
        .read(appPreferencesProvider.notifier)
        .completeOnboarding(setup);

    expect(repository.value.onboardingComplete, isTrue);
    expect(repository.value.reminderHour, 7);
    expect(repository.value.reminderMinute, 30);
    expect(repository.value.translationLanguage, 'French');
    expect(container.read(appPreferencesProvider).value, repository.value);
  });
}
