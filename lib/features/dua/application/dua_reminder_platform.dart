import 'package:android_intent_plus/android_intent.dart';
import 'package:ayyam/core/platform/runtime_platform.dart';
import 'package:ayyam/features/dua/domain/dua.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

final selectedDuaDayProvider =
    NotifierProvider<SelectedDuaDayController, DateTime?>(
      SelectedDuaDayController.new,
    );

final duaReminderPlatformProvider = Provider<DuaReminderPlatform>((ref) {
  return FlutterDuaReminderPlatform(
    onDaySelected: ref.read(selectedDuaDayProvider.notifier).select,
    onLifeSelected: ref.read(selectedLifeReminderProvider.notifier).select,
  );
});

final selectedLifeReminderProvider =
    NotifierProvider<SelectedLifeReminderController, bool>(
      SelectedLifeReminderController.new,
    );

class SelectedDuaDayController extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  void select(DateTime day) {
    state = DateTime(day.year, day.month, day.day);
  }

  void clear() => state = null;
}

class SelectedLifeReminderController extends Notifier<bool> {
  @override
  bool build() => false;

  void select() => state = true;

  void clear() => state = false;
}

class ReminderDeliveryStatus {
  const ReminderDeliveryStatus({
    required this.supported,
    this.notificationsAllowed,
    this.exactAlarmsAllowed,
  });

  const ReminderDeliveryStatus.unsupported()
    : supported = false,
      notificationsAllowed = null,
      exactAlarmsAllowed = null;

  final bool supported;
  final bool? notificationsAllowed;
  final bool? exactAlarmsAllowed;
}

abstract interface class DuaReminderPlatform {
  Future<void> initialize();

  Future<ReminderDeliveryStatus> deliveryStatus();

  Future<ReminderDeliveryStatus> requestPermissions();

  Future<void> replaceScheduled({
    required List<Dua> duas,
    required int hour,
    required int minute,
  });

  Future<void> cancelScheduled();

  Future<void> replaceLifeCheckInReminder({
    required bool enabled,
    required int hour,
    required int minute,
  });

  Future<void> openNotificationSettings();

  Future<void> openBatteryOptimizationSettings();
}

class FlutterDuaReminderPlatform implements DuaReminderPlatform {
  factory FlutterDuaReminderPlatform({
    required void Function(DateTime day) onDaySelected,
    required void Function() onLifeSelected,
    FlutterLocalNotificationsPlugin? plugin,
  }) => FlutterDuaReminderPlatform._(
    onDaySelected,
    onLifeSelected,
    plugin ?? FlutterLocalNotificationsPlugin(),
  );

  FlutterDuaReminderPlatform._(
    this._onDaySelected,
    this._onLifeSelected,
    this._plugin,
  );

  static const String _payloadPrefix = 'ayyam:dua:';
  static const String _lifePayload = 'ayyam:life:today';
  static const String _channelId = 'ayyam_daily_dua';
  static const String _lifeChannelId = 'ayyam_prayer_check_in';
  static const int _lifeNotificationId = 910001;

  final void Function(DateTime day) _onDaySelected;
  final void Function() _onLifeSelected;
  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized || !isAndroidRuntime) return;
    tz.initializeTimeZones();
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier));
    } catch (_) {
      // The timezone database remains usable with its UTC default.
    }

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_ayyam'),
      ),
      onDidReceiveNotificationResponse: (response) {
        _selectPayload(response.payload);
      },
    );
    _initialized = true;

    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      _selectPayload(launch?.notificationResponse?.payload);
    }
  }

  @override
  Future<ReminderDeliveryStatus> deliveryStatus() async {
    if (!isAndroidRuntime) {
      return const ReminderDeliveryStatus.unsupported();
    }
    await initialize();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return ReminderDeliveryStatus(
      supported: true,
      notificationsAllowed: await android?.areNotificationsEnabled(),
      exactAlarmsAllowed: await android?.canScheduleExactNotifications(),
    );
  }

  @override
  Future<ReminderDeliveryStatus> requestPermissions() async {
    if (!isAndroidRuntime) {
      return const ReminderDeliveryStatus.unsupported();
    }
    await initialize();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
    return deliveryStatus();
  }

  @override
  Future<void> replaceScheduled({
    required List<Dua> duas,
    required int hour,
    required int minute,
  }) async {
    if (!isAndroidRuntime) return;
    await initialize();
    await cancelScheduled();
    final status = await deliveryStatus();
    final scheduleMode = status.exactAlarmsAllowed == true
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    final now = tz.TZDateTime.now(tz.local);

    for (final dua in duas) {
      if (dua.flagged) continue;
      final date = dua.assignedDate;
      final scheduled = tz.TZDateTime(
        tz.local,
        date.year,
        date.month,
        date.day,
        hour,
        minute,
      );
      if (!scheduled.isAfter(now)) continue;
      await _plugin.zonedSchedule(
        id: notificationIdForDay(date),
        scheduledDate: scheduled,
        title: 'Today’s sourced dua',
        body: notificationPreview(dua.translation),
        payload: notificationPayloadForDay(date),
        androidScheduleMode: scheduleMode,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Daily dua',
            channelDescription: 'A sourced supplication prepared for the day.',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            category: AndroidNotificationCategory.reminder,
          ),
        ),
      );
    }
  }

  @override
  Future<void> cancelScheduled() async {
    if (!isAndroidRuntime) return;
    await initialize();
    final pending = await _plugin.pendingNotificationRequests();
    for (final request in pending) {
      if (request.payload?.startsWith(_payloadPrefix) ?? false) {
        await _plugin.cancel(id: request.id);
      }
    }
  }

  @override
  Future<void> replaceLifeCheckInReminder({
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    if (!isAndroidRuntime) return;
    await initialize();
    await _plugin.cancel(id: _lifeNotificationId);
    if (!enabled) return;

    final status = await deliveryStatus();
    final scheduleMode = status.exactAlarmsAllowed == true
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    await _plugin.zonedSchedule(
      id: _lifeNotificationId,
      scheduledDate: scheduled,
      title: 'How was today’s prayer day?',
      body: 'Take a quiet moment to record today in Life in Dots.',
      payload: _lifePayload,
      androidScheduleMode: scheduleMode,
      matchDateTimeComponents: DateTimeComponents.time,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _lifeChannelId,
          'Prayer check-in',
          channelDescription: 'An optional daily Life in Dots check-in.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          category: AndroidNotificationCategory.reminder,
        ),
      ),
    );
  }

  @override
  Future<void> openNotificationSettings() async {
    if (!isAndroidRuntime) return;
    await initialize();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.openAppNotificationSettings();
  }

  @override
  Future<void> openBatteryOptimizationSettings() async {
    if (!isAndroidRuntime) return;
    const intent = AndroidIntent(
      action: 'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS',
    );
    await intent.launch();
  }

  void _selectPayload(String? payload) {
    if (payload == _lifePayload) {
      _onLifeSelected();
      return;
    }
    final day = notificationDayFromPayload(payload);
    if (day != null) _onDaySelected(day);
  }
}

int notificationIdForDay(DateTime day) =>
    day.year * 10000 + day.month * 100 + day.day;

String notificationPayloadForDay(DateTime day) {
  final month = day.month.toString().padLeft(2, '0');
  final date = day.day.toString().padLeft(2, '0');
  return '${FlutterDuaReminderPlatform._payloadPrefix}${day.year}-$month-$date';
}

DateTime? notificationDayFromPayload(String? payload) {
  if (payload == null ||
      !payload.startsWith(FlutterDuaReminderPlatform._payloadPrefix)) {
    return null;
  }
  return DateTime.tryParse(
    payload.substring(FlutterDuaReminderPlatform._payloadPrefix.length),
  );
}

String notificationPreview(String translation, {int maxLength = 120}) {
  final normalized = translation.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.length <= maxLength) return normalized;
  return '${normalized.substring(0, maxLength - 1).trimRight()}…';
}
