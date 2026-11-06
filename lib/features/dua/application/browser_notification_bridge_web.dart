import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

class BrowserNotificationRequest {
  const BrowserNotificationRequest({
    required this.id,
    required this.scheduledAt,
    required this.title,
    required this.body,
    required this.payload,
  });

  final int id;
  final DateTime scheduledAt;
  final String title;
  final String body;
  final String payload;
}

class BrowserNotificationBridge {
  BrowserNotificationBridge(this._onPayload);

  final void Function(String?) _onPayload;
  final Map<int, Timer> _scheduled = <int, Timer>{};

  web.ServiceWorkerRegistration? _registration;
  Timer? _dailyTimer;
  Future<void>? _initializing;
  bool _listening = false;

  bool get supported {
    try {
      return web.window.isSecureContext &&
          web.window.hasProperty('Notification'.toJS).toDart &&
          web.window.navigator.hasProperty('serviceWorker'.toJS).toDart;
    } catch (_) {
      return false;
    }
  }

  bool? get notificationsAllowed {
    if (!supported) return null;
    return switch (web.Notification.permission) {
      'granted' => true,
      'denied' => false,
      _ => null,
    };
  }

  Future<void> initialize() =>
      _initializing ??= _initialize().catchError((_) {});

  Future<void> _initialize() async {
    if (!supported) return;
    final serviceWorker = web.window.navigator.serviceWorker;
    final workerUri = Uri.base.resolve('notification_service_worker.js');
    final scopeUri = Uri.base.resolve('notification-worker/');
    _registration = await serviceWorker
        .register(
          workerUri.toString().toJS,
          web.RegistrationOptions(scope: scopeUri.path),
        )
        .toDart;

    if (!_listening) {
      serviceWorker.onmessage = ((web.MessageEvent event) {
        final data = event.data;
        if (data != null && data.typeofEquals('string')) {
          _onPayload((data as JSString).toDart);
        }
      }).toJS;
      _listening = true;
    }

    _selectLaunchPayload();
  }

  void _selectLaunchPayload() {
    final uri = Uri.base;
    final payload = uri.queryParameters['notification_payload'];
    if (payload == null || payload.isEmpty) return;
    scheduleMicrotask(() => _onPayload(payload));

    final cleaned = Map<String, String>.from(uri.queryParameters)
      ..remove('notification_id')
      ..remove('notification_payload');
    final cleanedUri = uri.replace(
      queryParameters: cleaned.isEmpty ? null : cleaned,
    );
    web.window.history.replaceState(
      null,
      '',
      '${cleanedUri.path}'
          '${cleanedUri.hasQuery ? '?${cleanedUri.query}' : ''}'
          '${cleanedUri.hasFragment ? '#${cleanedUri.fragment}' : ''}',
    );
  }

  Future<bool?> requestPermissions() async {
    if (!supported) return null;
    if (notificationsAllowed case final allowed?) return allowed;
    final result = await web.Notification.requestPermission().toDart;
    unawaited(initialize());
    return result.toDart == 'granted';
  }

  Future<void> replaceScheduled(
    List<BrowserNotificationRequest> requests,
  ) async {
    await initialize();
    await cancelScheduled();
    final now = DateTime.now();
    for (final request in requests) {
      final delay = request.scheduledAt.difference(now);
      if (delay <= Duration.zero) continue;
      _scheduled[request.id] = Timer(delay, () {
        _scheduled.remove(request.id);
        unawaited(
          showNow(
            id: request.id,
            title: request.title,
            body: request.body,
            payload: request.payload,
          ),
        );
      });
    }
  }

  Future<void> cancelScheduled() async {
    for (final timer in _scheduled.values) {
      timer.cancel();
    }
    _scheduled.clear();
  }

  Future<void> replaceDaily({
    required bool enabled,
    required int hour,
    required int minute,
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {
    await initialize();
    _dailyTimer?.cancel();
    _dailyTimer = null;
    if (!enabled) return;

    void scheduleNext() {
      final now = DateTime.now();
      var scheduled = DateTime(now.year, now.month, now.day, hour, minute);
      if (!scheduled.isAfter(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }
      _dailyTimer = Timer(scheduled.difference(now), () {
        unawaited(showNow(id: id, title: title, body: body, payload: payload));
        scheduleNext();
      });
    }

    scheduleNext();
  }

  Future<bool> showNow({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {
    if (notificationsAllowed != true) return false;
    await initialize();
    final registration = _registration;
    if (registration == null || !await _waitUntilActive(registration)) {
      return false;
    }
    final icon = Uri.base.resolve('icons/Icon-192.png').toString();
    await registration
        .showNotification(
          title,
          web.NotificationOptions(
            body: body,
            tag: '$id',
            icon: icon,
            badge: icon,
            data: payload.toJS,
            renotify: true,
          ),
        )
        .toDart;
    return true;
  }

  Future<bool> _waitUntilActive(
    web.ServiceWorkerRegistration registration,
  ) async {
    for (var attempt = 0; attempt < 50; attempt++) {
      if (registration.active != null) return true;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    return registration.active != null;
  }
}
