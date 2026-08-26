import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

enum SocketStatus { connecting, connected, disconnected, error }

class SocketClient {
  final String url;
  io.Socket? _socket;
  SocketStatus _status = SocketStatus.disconnected;

  final StreamController<SocketStatus> _statusController =
      StreamController<SocketStatus>.broadcast();

  final Map<String, List<Function(dynamic)>> _eventHandlers = {};

  SocketClient(this.url);

  Stream<SocketStatus> get status => _statusController.stream;
  SocketStatus get currentStatus => _status;
  bool get isConnected => _status == SocketStatus.connected;

  void connect(String? token) {
    if (_socket != null && _socket!.connected) return;

    debugPrint('🌐 [SOCKET] 🔌 Connecting to $url...');
    _updateStatus(SocketStatus.connecting);

    _socket = io.io(
        url,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .enableAutoConnect()
            .setAuth(token != null
                ? {'token': token, 'Authorization': 'Bearer $token'}
                : {})
            .setQuery(token != null ? {'token': token} : {})
            .setExtraHeaders(
                token != null ? {'Authorization': 'Bearer $token'} : {})
            .build());

    // Re-bind deduplicated socket event handlers
    _eventHandlers.forEach((event, handlers) {
      _socket!.off(event);
      _socket!.on(event, (data) {
        final currentHandlers =
            List<Function(dynamic)>.from(_eventHandlers[event] ?? []);
        for (var handler in currentHandlers) {
          handler(data);
        }
      });
    });

    _socket!.onConnect((_) {
      debugPrint('🌐 [SOCKET] ✅ Connected');
      _updateStatus(SocketStatus.connected);
    });

    _socket!.onDisconnect((_) {
      debugPrint('🌐 [SOCKET] ❌ Disconnected');
      _updateStatus(SocketStatus.disconnected);
    });

    _socket!.onConnectError((data) {
      debugPrint('🌐 [SOCKET] ⚠️ Connection Error: $data');
      _updateStatus(SocketStatus.error);
    });

    _socket!.onError((data) {
      debugPrint('🌐 [SOCKET] 🛑 Error: $data');
      _updateStatus(SocketStatus.error);
    });

    _socket!.onReconnect((_) => debugPrint('🌐 [SOCKET] 🔄 Reconnected'));
    _socket!.onReconnectAttempt(
        (data) => debugPrint('🌐 [SOCKET] ⏳ Reconnect Attempt: $data'));
    _socket!.onReconnectError(
        (data) => debugPrint('🌐 [SOCKET] ⚠️ Reconnect Error: $data'));
    _socket!
        .onReconnectFailed((_) => debugPrint('🌐 [SOCKET] ❌ Reconnect Failed'));
  }

  void _updateStatus(SocketStatus status) {
    _status = status;
    _statusController.add(status);
  }

  void on(String event, Function(dynamic) handler) {
    final handlers = _eventHandlers.putIfAbsent(event, () => []);
    if (!handlers.contains(handler)) {
      handlers.add(handler);
    }

    _socket?.off(event);
    _socket?.on(event, (data) {
      final currentHandlers =
          List<Function(dynamic)>.from(_eventHandlers[event] ?? []);
      for (var h in currentHandlers) {
        h(data);
      }
    });
  }

  void emit(String event, dynamic data) {
    if (_socket != null && _socket!.connected) {
      debugPrint('🌐 [SOCKET OUTGOING 📤] Event: [$event]\nData: $data');
      _socket!.emit(event, data);
    } else {
      debugPrint('🌐 [SOCKET ❌] Cannot emit [$event]: Socket not connected');
    }
  }

  void disconnect() {
    debugPrint('🌐 [SOCKET] 🔌 Disconnecting...');
    _socket?.disconnect();
    _socket = null;
    _updateStatus(SocketStatus.disconnected);
  }

  void dispose() {
    disconnect();
    _statusController.close();
  }
}
