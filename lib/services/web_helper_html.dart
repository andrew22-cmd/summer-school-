// Web implementation for requesting Notification permission and showing
// foreground notifications. This file is only used when compiled for web
// (via conditional import).
import 'dart:html' as html;

Future<String?> requestWebNotificationPermission() async {
  try {
    final perm = await html.Notification.requestPermission();
    return perm;
  } catch (e) {
    return null;
  }
}

Future<void> showWebNotification(
  String? title,
  String? body,
  Map<String, dynamic>? data,
) async {
  try {
    // Try to use the service worker registration to show the notification
    final reg = await html.window.navigator.serviceWorker?.getRegistration();
    if (reg != null) {
      try {
        await reg.showNotification(title ?? '', {
          'body': body,
          'data': data ?? {},
        });
        return;
      } catch (_) {
        // fall back to Notification constructor
      }
    }

    if (html.Notification.permission == 'granted') {
      html.Notification(title ?? '');
      return;
    }

    final perm = await html.Notification.requestPermission();
    if (perm == 'granted') {
      html.Notification(title ?? '');
    }
  } catch (e) {
    // ignore errors on web notification
    print('[web_helper_html] showWebNotification error: $e');
  }
}
