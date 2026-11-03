import 'dart:ui';

import 'package:ayyam/core/database/app_database.dart';
import 'package:ayyam/core/platform/runtime_platform.dart';
import 'package:ayyam/core/security/api_key_vault.dart';
import 'package:ayyam/core/settings/app_preferences_repository.dart';
import 'package:ayyam/features/dua/application/dua_buffer_service.dart';
import 'package:ayyam/features/dua/application/dua_generation_service.dart';
import 'package:ayyam/features/dua/application/dua_reminder_platform.dart';
import 'package:ayyam/features/dua/data/dua_repository.dart';
import 'package:ayyam/features/dua/data/gemini_dua_client.dart';
import 'package:ayyam/features/dua/domain/dua_validator.dart';
import 'package:http/http.dart' as http;
import 'package:workmanager/workmanager.dart';

const String duaBufferWorkName = 'ayyam.dua.buffer.periodic';
const String duaBufferTaskName = 'ayyam.dua.buffer.topUp';

abstract interface class DuaReminderWorkScheduler {
  Future<void> register();

  Future<void> cancel();
}

class AndroidDuaReminderWorkScheduler implements DuaReminderWorkScheduler {
  const AndroidDuaReminderWorkScheduler();

  @override
  Future<void> register() async {
    if (!isAndroidRuntime) return;
    await Workmanager().registerPeriodicTask(
      duaBufferWorkName,
      duaBufferTaskName,
      frequency: const Duration(hours: 12),
      initialDelay: const Duration(hours: 1),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    );
  }

  @override
  Future<void> cancel() async {
    if (!isAndroidRuntime) return;
    await Workmanager().cancelByUniqueName(duaBufferWorkName);
  }
}

Future<void> initializeDuaReminderBackgroundWork() async {
  if (!isAndroidRuntime) return;
  await Workmanager().initialize(duaReminderCallbackDispatcher);
}

@pragma('vm:entry-point')
void duaReminderCallbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName != duaBufferTaskName) return true;
    DartPluginRegistrant.ensureInitialized();
    return _runBackgroundSync();
  });
}

Future<bool> _runBackgroundSync() async {
  final preferences = await LocalAppPreferencesRepository().load();
  if (!preferences.onboardingComplete || !preferences.duaEnabled) return true;
  final apiKey = await ApiKeyVault().read();
  if (apiKey == null || apiKey.trim().isEmpty) return true;

  final database = AppDatabase.defaults();
  final client = http.Client();
  try {
    final repository = DriftDuaRepository(database);
    final generator = DuaGenerationService(
      repository: repository,
      client: GeminiDuaClient(client: client),
      validator: const DuaValidator(),
    );
    final buffer = DuaBufferService(
      repository: repository,
      preparer: generator,
    );
    final result = await buffer.topUp(
      today: DateTime.now(),
      apiKey: apiKey,
      language: preferences.translationLanguage,
    );
    final first = _dateOnly(DateTime.now());
    final duas = await repository.findAssignedBetween(
      first,
      first.add(const Duration(days: 5)),
    );
    final reminders = FlutterDuaReminderPlatform(onDaySelected: (_) {});
    await reminders.replaceScheduled(
      duas: duas,
      hour: preferences.reminderHour,
      minute: preferences.reminderMinute,
    );
    return result.failure == null;
  } catch (_) {
    return false;
  } finally {
    client.close();
    await database.close();
  }
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
