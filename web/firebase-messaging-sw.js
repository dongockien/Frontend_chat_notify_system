importScripts("https://www.gstatic.com/firebasejs/9.0.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/9.0.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyA5YaVAIhYGBspbu3z4oImTXgnHDUH06cQ",
  authDomain: "chat-notify-system.firebaseapp.com",
  projectId: "chat-notify-system",
  storageBucket: "chat-notify-system.firebasestorage.app",
  messagingSenderId: "103944605129",
  appId: "1:103944605129:web:595e35e747c604654f2c18" 
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function(payload) {
  console.log('Đã nhận tin nhắn chạy ngầm: ', payload);
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
   // icon: '/firebase-logo.png'
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});