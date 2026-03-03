import 'dart:convert';
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import 'firebase_options.dart';

int? myUserId;
String? myUserName;
String? globalJwtToken;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseMessaging.instance.requestPermission();
  runApp(const ChatApp());
}

class ChatApp extends StatelessWidget {
  const ChatApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Enterprise Chat',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const LoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _nameController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isLoading = true);
    print("BẮT ĐẦU: Đang gọi API Login với tên: $name");

    try {
      final res = await http.post(
        Uri.parse('http://localhost:8088/api/login?name=$name'),
      );
      print("KẾT QUẢ LOGIN: ${res.statusCode} - ${res.body}");

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        globalJwtToken = data['access_token'];
        myUserId = data['user_id'];
        myUserName = data['name'];

        try {
          String? fcmToken = await FirebaseMessaging.instance.getToken();
          if (fcmToken != null) {
            print("📲 Lấy được FCM Token: $fcmToken");
            await http.post(
              Uri.parse('http://localhost:8088/api/devices'),
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $globalJwtToken',
              },
              body: jsonEncode({"device_token": fcmToken, "platform": "web"}),
            );
          }
        } catch (fcmErr) {
          print("Bỏ qua lấy FCM Token (Tab Ẩn Danh chặn thông báo): $fcmErr");
        }

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ChatScreen()),
          );
        }
      } else {
        throw Exception("Server trả về lỗi ${res.statusCode}");
      }
    } catch (e) {
      print("LỖI ĐĂNG NHẬP: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Lỗi đăng nhập: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cổng Đăng Nhập')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Bạn tên là gì?", style: TextStyle(fontSize: 20)),
              const SizedBox(height: 20),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: "Nhập Tên của bạn (VD: Sếp Kiên)",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _login,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text("Vào Phòng Chat"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final TextEditingController _msgController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  WebSocketChannel? _channel;

  bool _isSocketConnected = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchHistory();
    _connectWebSocket();

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (mounted && message.notification != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "🔔 ${message.notification!.title}: ${message.notification!.body}",
            ),
            backgroundColor: Colors.orange[700],
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(top: 20, left: 20, right: 20),
          ),
        );
      }
    });
  }

  Future<void> _fetchHistory() async {
    try {
      final res = await http.get(
        Uri.parse('http://localhost:8088/api/messages?conversation_id=99'),
        headers: {'Authorization': 'Bearer $globalJwtToken'},
      );
      if (res.statusCode == 200) {
        final List<dynamic> historyData = jsonDecode(res.body)['data'] ?? [];
        if (mounted) {
          setState(() {
            _messages.clear();
            for (var msg in historyData) {
              _messages.add(msg);
            }
          });
        }
      }
    } catch (e) {
      print("❌ Lỗi tải lịch sử chat: $e");
    }
  }

  void _connectWebSocket() {
    if (_isSocketConnected) return;

    print("🔌 Đang kết nối WebSocket...");
    _channel = WebSocketChannel.connect(
      Uri.parse('ws://localhost:8088/ws?token=$globalJwtToken'),
    );
    _isSocketConnected = true;

    _channel!.stream.listen(
      (message) {
        final data = jsonDecode(message);
        if (mounted) {
          setState(() {
            if (data['type'] == 'system_alert') {
              _messages.add({'type': 'system', 'content': data['content']});
            } else if (data['type'] == 'chat' &&
                data['conversation_id'] == 99) {
              _messages.add({
                'type': 'chat',
                'content': data['content'],
                'sender_id': data['sender_id'],
                'sender_name': data['sender_name'],
              });
            }
          });
        }
      },
      onDone: () {
        _isSocketConnected = false;
      },
      onError: (error) {
        _isSocketConnected = false;
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      print("⏸️ Đã Out Tab / Ẩn App -> Ngắt Socket để Backend bắn Push FCM");
      _channel?.sink.close();
      _isSocketConnected = false;
    } else if (state == AppLifecycleState.resumed) {
      print("▶️ Đã quay lại Tab -> Tải lại Lịch sử & Nối lại Socket");
      _fetchHistory(); // 🔥 GỌI LẠI LÚC QUAY TRỞ VỀ APP ĐỂ BÙ TIN NHẮN BỊ LỠ
      _connectWebSocket();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _channel?.sink.close();
    super.dispose();
  }

  Future<void> _sendMsg() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    _msgController.clear();

    await http.post(
      Uri.parse('http://localhost:8088/api/messages'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $globalJwtToken',
      },
      body: jsonEncode({
        "conversation_id": 99,
        "receiver_ids": [1, 2, 3],
        "content": text,
      }),
    );
  }

  Future<void> _addMember() async {
    final randName = "Người Mới ${Random().nextInt(1000)}";
    await http.post(
      Uri.parse('http://localhost:8088/api/members/add?name=$randName'),
      headers: {'Authorization': 'Bearer $globalJwtToken'},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Phòng Chat (Bạn là: $myUserName)'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.person_add), onPressed: _addMember),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];

                if (msg['type'] == 'system') {
                  return Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        msg['content'],
                        style: const TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  );
                }

                bool isMe = msg['sender_id'] == myUserId;
                return Align(
                  alignment: isMe
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.blue[100] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: isMe
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        Text(
                          isMe ? "Bạn" : msg['sender_name'],
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blueGrey[600],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          msg['content'],
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgController,
                    decoration: const InputDecoration(
                      hintText: 'Nhập tin nhắn...',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue),
                  onPressed: _sendMsg,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
