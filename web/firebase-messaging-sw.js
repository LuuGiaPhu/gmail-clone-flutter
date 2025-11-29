importScripts('https://www.gstatic.com/firebasejs/10.11.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.11.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyCURbADuU8iBuXyOQMvQVCMwn5prNfME1o",
  authDomain: "flutter-email-459809.firebaseapp.com",
  projectId: "flutter-email-459809",
  storageBucket: "flutter-email-459809.firebasestorage.app",
  messagingSenderId: "141493579332",
  appId: "1:141493579332:web:1ab696e684c1f3b9781611",
  measurementId: "G-YQPXG9W7QC"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function(payload) {
  // Debug log để kiểm tra đã nhận được message chưa
  console.log('[firebase-messaging-sw.js] Received background message ', payload);

  // Lấy icon từ payload nếu có, fallback về icon mặc định
  const notificationIcon = payload.notification.icon || 'assets/gmail_logo.png';

  self.registration.showNotification(
    payload.notification.title,
    {
      body: payload.notification.body,
      icon: notificationIcon,
      data: payload.data // Đính kèm data để xử lý khi click
    }
  );
});

// Xử lý khi người dùng click vào notification (mở tab hoặc focus tab)
self.addEventListener('notificationclick', function(event) {
  event.notification.close();
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function(clientList) {
      for (const client of clientList) {
        if (client.url && 'focus' in client) {
          return client.focus();
        }
      }
      if (clients.openWindow) {
        return clients.openWindow('/');
      }
    })
  );
});