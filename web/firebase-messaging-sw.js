// Scripts for firebase messaging
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

// Initialize the Firebase app in the service worker by passing in the messagingSenderId.
firebase.initializeApp({
  apiKey: "AIzaSyAFEPKxCmxL5dtKAZD1Xt4d7XiWoHDQ6UY",
  appId: "1:339448653254:web:1e9d9ec9460c30ce073ec7",
  messagingSenderId: "339448653254",
  projectId: "vcloud-mobile",
  authDomain: "vcloud-mobile.firebaseapp.com",
  storageBucket: "vcloud-mobile.firebasestorage.app"
});

// Retrieve an instance of Firebase Messaging so that it can handle background messages.
const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  const notificationTitle = payload.notification ? payload.notification.title : 'Vcloud';
  const notificationOptions = {
    body: payload.notification ? payload.notification.body : '',
    icon: '/favicon.png'
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
