# Frontend_chat_notify_system
 TÍNH NĂNG CỐT LÕI (CORE FEATURES)
* **Xác thực & Định danh thiết bị:** Tự động đăng nhập, lưu trữ phiên làm việc bằng JWT và đăng ký `Device Token` với hệ thống Google Firebase Cloud Messaging (FCM).
* **Giao tiếp Thời gian thực (Real-time Messaging):** Sử dụng kết nối WebSocket hai chiều với API Gateway để gửi và nhận tin nhắn với độ trễ cực thấp (< 20ms).
* **Đồng bộ Lịch sử (History Sync):** Tự động gọi API HTTP để tải lại lịch sử tin nhắn khi ứng dụng khởi động hoặc khi khôi phục kết nối mạng.
* **Cảm biến Vòng đời Ứng dụng (App Lifecycle Smart Sensor):**
  * `Foreground` (Đang mở app): Duy trì kết nối WebSocket để nhận tin nhắn trực tiếp, tắt thông báo đẩy (Pop-up Push) để tránh làm phiền.
  * `Background/Terminated` (Ẩn/Đóng app): Tự động ngắt kết nối WebSocket. Lúc này hệ thống Backend sẽ nhận diện trạng thái Offline và chuyển hướng gửi thông báo qua Google FCM.

## 🛠️ CÔNG NGHỆ SỬ DỤNG (TECH STACK)

* **Framework:** Flutter (Dart)
* **Real-time Communication:** `web_socket_channel`
* **Push Notification:** `firebase_messaging`, `firebase_core`
* **Network & API:** `http` (RESTful API requests)
* **Local Storage:** `shared_preferences` (Lưu JWT Token cục bộ)
