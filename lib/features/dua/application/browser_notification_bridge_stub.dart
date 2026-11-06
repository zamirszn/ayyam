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
  BrowserNotificationBridge(void Function(String?) onPayload);

  bool get supported => false;

  bool? get notificationsAllowed => null;

  Future<void> initialize() async {}

  Future<bool?> requestPermissions() async => null;

  Future<void> replaceScheduled(
    List<BrowserNotificationRequest> requests,
  ) async {}

  Future<void> cancelScheduled() async {}

  Future<void> replaceDaily({
    required bool enabled,
    required int hour,
    required int minute,
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {}

  Future<bool> showNow({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async => false;
}
