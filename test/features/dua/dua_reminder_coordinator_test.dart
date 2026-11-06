import 'package:ayyam/core/security/api_key_vault.dart';
import 'package:ayyam/core/settings/app_preferences.dart';
import 'package:ayyam/features/dua/application/dua_buffer_service.dart';
import 'package:ayyam/features/dua/application/dua_generation_service.dart';
import 'package:ayyam/features/dua/application/dua_reminder_coordinator.dart';
import 'package:ayyam/features/dua/application/dua_reminder_platform.dart';
import 'package:ayyam/features/dua/application/dua_reminder_worker.dart';
import 'package:ayyam/features/dua/data/dua_repository.dart';
import 'package:ayyam/features/dua/domain/dua.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tops up five days and schedules their stored previews', () async {
    final repository = MemoryDuaRepository();
    final buffer = DuaBufferService(
      repository: repository,
      preparer: _SavingPreparer(repository),
    );
    final reminders = _MemoryReminders();
    final work = _MemoryWorkScheduler();
    final coordinator = DuaReminderCoordinator(
      repository: repository,
      buffer: buffer,
      vault: _MemoryVault('key'),
      reminders: reminders,
      workScheduler: work,
    );

    final result = await coordinator.sync(
      _preferences(),
      now: DateTime(2026, 11, 3, 12),
    );

    expect(result.bufferResult?.isFull, isTrue);
    expect(work.registered, isTrue);
    expect(reminders.hour, 6);
    expect(reminders.minute, 0);
    expect(reminders.duas, hasLength(5));
    expect(reminders.duas.first.assignedDate, DateTime(2026, 11, 4));
  });

  test('cancels reminders and background work when dua is disabled', () async {
    final repository = MemoryDuaRepository();
    final reminders = _MemoryReminders();
    final work = _MemoryWorkScheduler();
    final coordinator = DuaReminderCoordinator(
      repository: repository,
      buffer: DuaBufferService(
        repository: repository,
        preparer: _SavingPreparer(repository),
      ),
      vault: _MemoryVault('key'),
      reminders: reminders,
      workScheduler: work,
    );

    await coordinator.sync(
      _preferences().copyWith(duaEnabled: false),
      now: DateTime(2026, 11, 3),
    );

    expect(reminders.cancelled, isTrue);
    expect(work.cancelled, isTrue);
    expect(repository.values, isEmpty);
  });

  test('schedules a Life check-in independently of dua reminders', () async {
    final repository = MemoryDuaRepository();
    final reminders = _MemoryReminders();
    final work = _MemoryWorkScheduler();
    final coordinator = DuaReminderCoordinator(
      repository: repository,
      buffer: DuaBufferService(
        repository: repository,
        preparer: _SavingPreparer(repository),
      ),
      vault: _MemoryVault(null),
      reminders: reminders,
      workScheduler: work,
    );

    await coordinator.sync(
      _preferences().copyWith(
        duaEnabled: false,
        lifeInDotsEnabled: true,
        lifeReminderEnabled: true,
        lifeReminderHour: 21,
        lifeReminderMinute: 15,
      ),
      now: DateTime(2026, 11, 3),
    );

    expect(reminders.lifeEnabled, isTrue);
    expect(reminders.lifeHour, 21);
    expect(reminders.lifeMinute, 15);
    expect(reminders.cancelled, isTrue);
    expect(work.cancelled, isTrue);
  });

  test('notification payload and preview are stable and bounded', () {
    final day = DateTime(2026, 11, 4);
    final payload = notificationPayloadForDay(day);

    expect(notificationIdForDay(day), 20261104);
    expect(notificationDayFromPayload(payload), day);
    expect(notificationDayFromPayload('other'), isNull);
    expect(notificationPreview('  one\n two  '), 'one two');
    expect(notificationPreview('x' * 150), hasLength(120));
    expect(notificationPreview('x' * 150), endsWith('…'));
  });
}

class _SavingPreparer implements DuaPreparer {
  _SavingPreparer(this.repository);

  final DuaRepository repository;
  int sequence = 0;

  @override
  Future<Dua> prepareForDate({
    required DateTime date,
    required String apiKey,
    required String language,
    DuaStatus status = DuaStatus.shown,
    DateTime Function()? now,
  }) async {
    sequence++;
    final dua = Dua(
      id: 'dua-$sequence',
      arabic: 'رَبَّنَا دُعَاء $sequence',
      transliteration: 'Rabbana dua $sequence.',
      translation: 'Translation $sequence',
      benefits: 'Context',
      occasion: 'General',
      sources: const <DuaSource>[
        DuaSource(
          type: DuaSourceType.quran,
          collection: 'Quran',
          reference: '2:201',
          grading: 'Quran',
        ),
      ],
      assignedDate: date,
      status: status,
      generatedAt: date,
    );
    await repository.save(dua);
    return dua;
  }
}

class _MemoryVault extends ApiKeyVault {
  _MemoryVault(this.value);

  final String? value;

  @override
  Future<String?> read() async => value;
}

class _MemoryReminders implements DuaReminderPlatform {
  bool cancelled = false;
  int? hour;
  int? minute;
  List<Dua> duas = const <Dua>[];
  bool? lifeEnabled;
  int? lifeHour;
  int? lifeMinute;

  @override
  Future<void> cancelScheduled() async => cancelled = true;

  @override
  Future<ReminderDeliveryStatus> deliveryStatus() async =>
      const ReminderDeliveryStatus(
        supported: true,
        notificationsAllowed: true,
        exactAlarmsAllowed: true,
      );

  @override
  Future<void> initialize() async {}

  @override
  Future<void> openBatteryOptimizationSettings() async {}

  @override
  Future<void> openNotificationSettings() async {}

  @override
  Future<void> replaceLifeCheckInReminder({
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    lifeEnabled = enabled;
    lifeHour = hour;
    lifeMinute = minute;
  }

  @override
  Future<void> replaceScheduled({
    required List<Dua> duas,
    required int hour,
    required int minute,
  }) async {
    this.duas = List<Dua>.from(duas);
    this.hour = hour;
    this.minute = minute;
  }

  @override
  Future<bool> showTestNotification() async => true;

  @override
  Future<ReminderDeliveryStatus> requestPermissions() => deliveryStatus();
}

class _MemoryWorkScheduler implements DuaReminderWorkScheduler {
  bool registered = false;
  bool cancelled = false;

  @override
  Future<void> cancel() async => cancelled = true;

  @override
  Future<void> register() async => registered = true;
}

AppPreferences _preferences() => AppPreferences.defaults.copyWith(
  onboardingComplete: true,
  duaEnabled: true,
  lifeInDotsEnabled: false,
);
