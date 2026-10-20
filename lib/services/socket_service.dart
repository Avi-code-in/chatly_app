import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  late IO.Socket socket;
  bool isConnected = false;

  void connect() {
    if (isConnected) return;

    // Aapka Render Backend URL
    socket = IO.io('https://chatly-call-backend.onrender.com', 
      IO.OptionBuilder()
        .setTransports(['websocket'])
        .disableAutoConnect()
        .build()
    );

    socket.connect();

    socket.onConnect((_) {
      print('✅ Socket Connected to Backend');
      isConnected = true;
    });

    socket.onDisconnect((_) {
      print('❌ Socket Disconnected');
      isConnected = false;
    });

    socket.onConnectError((err) => print('Connect Error: $err'));
  }

  // Call Events
  void emitCallUser(Map<String, dynamic> data) => socket.emit('call-user', data);
  void emitAnswerCall(Map<String, dynamic> data) => socket.emit('answer-call', data);
  void emitIceCandidate(Map<String, dynamic> data) => socket.emit('ice-candidate', data);
  void emitEndCall(Map<String, dynamic> data) => socket.emit('end-call', data);
  void emitRejectCall(Map<String, dynamic> data) => socket.emit('reject-call', data);
}
