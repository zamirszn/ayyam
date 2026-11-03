import 'package:ayyam/core/settings/app_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class AppPreferencesRepository {
  Future<AppPreferences> load();

  Future<void> save(AppPreferences preferences);
}

class LocalAppPreferencesRepository implements AppPreferencesRepository {
  LocalAppPreferencesRepository({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  static const String _onboardingComplete = 'ayyam.settings.onboardingComplete';
  static const String _duaEnabled = 'ayyam.settings.duaEnabled';
  static const String _lifeInDotsEnabled = 'ayyam.settings.lifeInDotsEnabled';
  static const String _reminderHour = 'ayyam.settings.reminderHour';
  static const String _reminderMinute = 'ayyam.settings.reminderMinute';
  static const String _translationLanguage =
      'ayyam.settings.translationLanguage';
  static const String _dateOfBirth = 'ayyam.settings.dateOfBirth';
  static const String _missedPrayerYears = 'ayyam.settings.missedPrayerYears';
  static const String _lifeReminderEnabled =
      'ayyam.settings.lifeReminderEnabled';
  static const String _lifeReminderHour = 'ayyam.settings.lifeReminderHour';
  static const String _lifeReminderMinute = 'ayyam.settings.lifeReminderMinute';

  @override
  Future<AppPreferences> load() async {
    final values = await Future.wait<Object?>(<Future<Object?>>[
      _preferences.getBool(_onboardingComplete),
      _preferences.getBool(_duaEnabled),
      _preferences.getBool(_lifeInDotsEnabled),
      _preferences.getInt(_reminderHour),
      _preferences.getInt(_reminderMinute),
      _preferences.getString(_translationLanguage),
      _preferences.getString(_dateOfBirth),
      _preferences.getInt(_missedPrayerYears),
      _preferences.getBool(_lifeReminderEnabled),
      _preferences.getInt(_lifeReminderHour),
      _preferences.getInt(_lifeReminderMinute),
    ]);
    final dateValue = values[6] as String?;

    return AppPreferences(
      onboardingComplete:
          values[0] as bool? ?? AppPreferences.defaults.onboardingComplete,
      duaEnabled: values[1] as bool? ?? AppPreferences.defaults.duaEnabled,
      lifeInDotsEnabled:
          values[2] as bool? ?? AppPreferences.defaults.lifeInDotsEnabled,
      reminderHour: values[3] as int? ?? AppPreferences.defaults.reminderHour,
      reminderMinute:
          values[4] as int? ?? AppPreferences.defaults.reminderMinute,
      translationLanguage:
          values[5] as String? ?? AppPreferences.defaults.translationLanguage,
      dateOfBirth: dateValue == null ? null : DateTime.tryParse(dateValue),
      missedPrayerYears:
          values[7] as int? ?? AppPreferences.defaults.missedPrayerYears,
      lifeReminderEnabled:
          values[8] as bool? ?? AppPreferences.defaults.lifeReminderEnabled,
      lifeReminderHour:
          values[9] as int? ?? AppPreferences.defaults.lifeReminderHour,
      lifeReminderMinute:
          values[10] as int? ?? AppPreferences.defaults.lifeReminderMinute,
    );
  }

  @override
  Future<void> save(AppPreferences preferences) async {
    await Future.wait<void>(<Future<void>>[
      _preferences.setBool(_onboardingComplete, preferences.onboardingComplete),
      _preferences.setBool(_duaEnabled, preferences.duaEnabled),
      _preferences.setBool(_lifeInDotsEnabled, preferences.lifeInDotsEnabled),
      _preferences.setInt(_reminderHour, preferences.reminderHour),
      _preferences.setInt(_reminderMinute, preferences.reminderMinute),
      _preferences.setString(
        _translationLanguage,
        preferences.translationLanguage,
      ),
      _preferences.setInt(_missedPrayerYears, preferences.missedPrayerYears),
      _preferences.setBool(
        _lifeReminderEnabled,
        preferences.lifeReminderEnabled,
      ),
      _preferences.setInt(_lifeReminderHour, preferences.lifeReminderHour),
      _preferences.setInt(_lifeReminderMinute, preferences.lifeReminderMinute),
      if (preferences.dateOfBirth case final date?)
        _preferences.setString(_dateOfBirth, date.toIso8601String())
      else
        _preferences.remove(_dateOfBirth),
    ]);
  }
}

class MemoryAppPreferencesRepository implements AppPreferencesRepository {
  MemoryAppPreferencesRepository([this.value = AppPreferences.defaults]);

  AppPreferences value;

  @override
  Future<AppPreferences> load() async => value;

  @override
  Future<void> save(AppPreferences preferences) async {
    value = preferences;
  }
}
