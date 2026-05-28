// firebase-messaging-sw.js
// Service worker for Firebase Cloud Messaging (Web).
// IMPORTANT: Fill the firebaseConfig below with your Firebase project's
// web config values from the Firebase Console (apiKey, authDomain, projectId,
// storageBucket, messagingSenderId, appId, measurementId).

importScripts('https://www.gstatic.com/firebasejs/9.22.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.22.1/firebase-messaging-compat.js');

// TODO: Replace the config object with your project's config
const firebaseConfig = {
  apiKey: "AIzaSyD8rK4eG8GRZcs9FQP7j2-lzUIMVf02R1g",
  authDomain: "summer-school-2f0a7.firebaseapp.com",
  projectId: "summer-school-2f0a7",
  storageBucket: "summer-school-2f0a7.firebasestorage.app",
  messagingSenderId: "279809808505",
  appId: "1:279809808505:web:1529e1fd08f744b0df1ca8",
  measurementId: "G-7MZMNMV7RE"
};

firebase.initializeApp(firebaseConfig);

const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage(function(payload) {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  const notificationTitle = payload.notification?.title || 'Background Message';
  const notificationOptions = {
    body: payload.notification?.body || '',
    data: payload.data || {},
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});
