import 'dart:html' as html;

void registerServiceWorker() {
  if (html.window.navigator.serviceWorker != null) {
    html.window.navigator.serviceWorker!.register('firebase-messaging-sw.js');
  }
}

Future<void> showWebNotification(String title, String body, {String? icon}) async {
  if (html.Notification.permission != 'granted') {
    await html.Notification.requestPermission();
  }
  if (html.Notification.permission == 'granted') {
    html.Notification(title, body: body, icon: icon);
  }
}