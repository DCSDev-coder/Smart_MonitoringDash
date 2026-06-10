importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js");

const firebaseConfig = {
  apiKey: "AIzaSyAnoPlaPA9kUOX5YIChT5M0_odKJQoD2us",
  authDomain: "smartrack-f737a.firebaseapp.com",
  projectId: "smartrack-f737a",
  storageBucket: "smartrack-f737a.firebasestorage.app",
  messagingSenderId: "1042621674847",
  appId: "1:1042621674847:web:94c69b851c89a26f25f2ea",
  measurementId: "G-XS3Z60L630"
};

firebase.initializeApp(firebaseConfig);

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);

  const notificationTitle = payload.notification?.title || 'Smart Rack Alert';
  const notificationOptions = {
    body: payload.notification?.body || 'A new alert has arrived.',
    icon: '/icons/Icon-192.png'
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
