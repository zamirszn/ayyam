import 'package:flutter/foundation.dart';

@immutable
class AppPreferences {
  const AppPreferences({
    required this.onboardingComplete,
    required this.duaEnabled,
    required this.lifeInDotsEnabled,
    required this.reminderHour,
    required this.reminderMinute,
    required this.translationLanguage,
    required this.dateOfBirth,
    required this.missedPrayerYears,
    this.lifeReminderEnabled = false,
    this.lifeReminderHour = 20,
    this.lifeReminderMinute = 0,
  });

  final bool onboardingComplete;
  final bool duaEnabled;
  final bool lifeInDotsEnabled;
  final int reminderHour;
  final int reminderMinute;
  final String translationLanguage;
  final DateTime? dateOfBirth;
  final int missedPrayerYears;
  final bool lifeReminderEnabled;
  final int lifeReminderHour;
  final int lifeReminderMinute;

  static const AppPreferences defaults = AppPreferences(
    onboardingComplete: false,
    duaEnabled: true,
    lifeInDotsEnabled: true,
    reminderHour: 6,
    reminderMinute: 0,
    translationLanguage: 'English',
    dateOfBirth: null,
    missedPrayerYears: 0,
    lifeReminderEnabled: false,
    lifeReminderHour: 20,
    lifeReminderMinute: 0,
  );

  AppPreferences copyWith({
    bool? onboardingComplete,
    bool? duaEnabled,
    bool? lifeInDotsEnabled,
    int? reminderHour,
    int? reminderMinute,
    String? translationLanguage,
    DateTime? dateOfBirth,
    bool clearDateOfBirth = false,
    int? missedPrayerYears,
    bool? lifeReminderEnabled,
    int? lifeReminderHour,
    int? lifeReminderMinute,
  }) {
    return AppPreferences(
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      duaEnabled: duaEnabled ?? this.duaEnabled,
      lifeInDotsEnabled: lifeInDotsEnabled ?? this.lifeInDotsEnabled,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
      translationLanguage: translationLanguage ?? this.translationLanguage,
      dateOfBirth: clearDateOfBirth ? null : (dateOfBirth ?? this.dateOfBirth),
      missedPrayerYears: missedPrayerYears ?? this.missedPrayerYears,
      lifeReminderEnabled: lifeReminderEnabled ?? this.lifeReminderEnabled,
      lifeReminderHour: lifeReminderHour ?? this.lifeReminderHour,
      lifeReminderMinute: lifeReminderMinute ?? this.lifeReminderMinute,
    );
  }
}

@immutable
class OnboardingSetup {
  const OnboardingSetup({
    required this.duaEnabled,
    required this.lifeInDotsEnabled,
    required this.reminderHour,
    required this.reminderMinute,
    required this.translationLanguage,
    required this.dateOfBirth,
    required this.missedPrayerYears,
  });

  final bool duaEnabled;
  final bool lifeInDotsEnabled;
  final int reminderHour;
  final int reminderMinute;
  final String translationLanguage;
  final DateTime? dateOfBirth;
  final int missedPrayerYears;

  AppPreferences toPreferences() => AppPreferences(
    onboardingComplete: true,
    duaEnabled: duaEnabled,
    lifeInDotsEnabled: lifeInDotsEnabled,
    reminderHour: reminderHour,
    reminderMinute: reminderMinute,
    translationLanguage: translationLanguage,
    dateOfBirth: dateOfBirth,
    missedPrayerYears: missedPrayerYears,
    lifeReminderEnabled: false,
    lifeReminderHour: 20,
    lifeReminderMinute: 0,
  );
}
