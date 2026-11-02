import 'package:ayyam/core/settings/app_preferences.dart';
import 'package:ayyam/core/settings/app_preferences_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appPreferencesRepositoryProvider = Provider<AppPreferencesRepository>(
  (ref) => LocalAppPreferencesRepository(),
);

final appPreferencesProvider =
    AsyncNotifierProvider<AppPreferencesController, AppPreferences>(
      AppPreferencesController.new,
    );

class AppPreferencesController extends AsyncNotifier<AppPreferences> {
  @override
  Future<AppPreferences> build() {
    return ref.watch(appPreferencesRepositoryProvider).load();
  }

  Future<void> completeOnboarding(OnboardingSetup setup) async {
    final preferences = setup.toPreferences();
    await ref.read(appPreferencesRepositoryProvider).save(preferences);
    state = AsyncData<AppPreferences>(preferences);
  }

  Future<void> updatePreferences(AppPreferences preferences) async {
    await ref.read(appPreferencesRepositoryProvider).save(preferences);
    state = AsyncData<AppPreferences>(preferences);
  }
}
