import 'package:ayyam/core/security/api_key_vault.dart';
import 'package:ayyam/core/settings/app_preferences.dart';
import 'package:ayyam/features/dua/application/dua_buffer_service.dart';
import 'package:ayyam/features/dua/application/dua_reminder_platform.dart';
import 'package:ayyam/features/dua/application/dua_reminder_worker.dart';
import 'package:ayyam/features/dua/data/dua_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final duaReminderWorkSchedulerProvider = Provider<DuaReminderWorkScheduler>(
  (ref) => const AndroidDuaReminderWorkScheduler(),
);

final duaReminderCoordinatorProvider = Provider<DuaReminderCoordinator>((ref) {
  return DuaReminderCoordinator(
    repository: ref.watch(duaRepositoryProvider),
    buffer: ref.watch(duaBufferServiceProvider),
    vault: ref.watch(apiKeyVaultProvider),
    reminders: ref.watch(duaReminderPlatformProvider),
    workScheduler: ref.watch(duaReminderWorkSchedulerProvider),
  );
});

class DuaReminderSyncResult {
  const DuaReminderSyncResult({this.bufferResult});

  final DuaBufferResult? bufferResult;
}

class DuaReminderCoordinator {
  factory DuaReminderCoordinator({
    required DuaRepository repository,
    required DuaBufferService buffer,
    required ApiKeyVault vault,
    required DuaReminderPlatform reminders,
    required DuaReminderWorkScheduler workScheduler,
  }) => DuaReminderCoordinator._(
    repository,
    buffer,
    vault,
    reminders,
    workScheduler,
  );

  const DuaReminderCoordinator._(
    this._repository,
    this._buffer,
    this._vault,
    this._reminders,
    this._workScheduler,
  );

  final DuaRepository _repository;
  final DuaBufferService _buffer;
  final ApiKeyVault _vault;
  final DuaReminderPlatform _reminders;
  final DuaReminderWorkScheduler _workScheduler;

  Future<DuaReminderSyncResult> sync(
    AppPreferences preferences, {
    DateTime? now,
  }) async {
    await _reminders.initialize();
    if (!preferences.onboardingComplete) {
      await _reminders.cancelScheduled();
      await _reminders.replaceLifeCheckInReminder(
        enabled: false,
        hour: preferences.lifeReminderHour,
        minute: preferences.lifeReminderMinute,
      );
      await _workScheduler.cancel();
      return const DuaReminderSyncResult();
    }

    await _reminders.replaceLifeCheckInReminder(
      enabled: preferences.lifeInDotsEnabled && preferences.lifeReminderEnabled,
      hour: preferences.lifeReminderHour,
      minute: preferences.lifeReminderMinute,
    );

    if (!preferences.duaEnabled) {
      await _reminders.cancelScheduled();
      await _workScheduler.cancel();
      return const DuaReminderSyncResult();
    }

    await _workScheduler.register();
    final today = _dateOnly(now ?? DateTime.now());
    final apiKey = await _vault.read();
    DuaBufferResult? result;
    if (apiKey != null && apiKey.trim().isNotEmpty) {
      result = await _buffer.topUp(
        today: today,
        apiKey: apiKey,
        language: preferences.translationLanguage,
      );
    }

    final duas = await _repository.findAssignedBetween(
      today,
      today.add(const Duration(days: 5)),
    );
    await _reminders.replaceScheduled(
      duas: duas,
      hour: preferences.reminderHour,
      minute: preferences.reminderMinute,
    );
    return DuaReminderSyncResult(bufferResult: result);
  }
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
