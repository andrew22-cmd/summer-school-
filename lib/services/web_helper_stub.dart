// Stub for non-web platforms.
Future<String?> requestWebNotificationPermission() async {
  // Not available on non-web platforms.
  return null;
}

Future<void> showWebNotification(
  String? title,
  String? body,
  Map<String, dynamic>? data,
) async {
  // no-op on non-web
  return;
}
