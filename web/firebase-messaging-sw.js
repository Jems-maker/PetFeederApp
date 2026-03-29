importScripts("https://www.gstatic.com/firebasejs/8.10.0/firebase-app.js");
importScripts("https://www.gstatic.com/firebasejs/8.10.0/firebase-messaging.js");

firebase.initializeApp({
  apiKey: "AIzaSyAvkqAjZb-xkTtiLGcp1TvmG04PoN8cOSk",
  authDomain: "petfeeder-c22df.firebaseapp.com",
  databaseURL: "https://petfeeder-c22df-default-rtdb.firebaseio.com",
  projectId: "petfeeder-c22df",
  storageBucket: "petfeeder-c22df.firebasestorage.app",
  messagingSenderId: "634672886656",
  appId: "1:634672886656:web:054c863e24203372efc765",
  measurementId: "G-VTT3S7DCSQ"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function(payload) {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  // Customize notification here
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/icons/Icon-192.png'
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
