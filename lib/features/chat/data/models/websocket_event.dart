import 'dart:convert';

enum WebSocketEventType {
  newMessage,
  deliveryReceipt,
  readReceipt,
  typingIndicator,
  presenceUpdate,
  syncRequired,
  error,
}

class WebSocketEvent {
  final WebSocketEventType type;
  final Map<String, dynamic> data;

  WebSocketEvent({
    required this.type,
    required this.data,
  });

  factory WebSocketEvent.fromMap(Map<String, dynamic> map) {
    return WebSocketEvent(
      type: WebSocketEventType.values.byName(map['type']),
      data: map['data'] ?? {},
    );
  }

  factory WebSocketEvent.fromJson(dynamic json) {
    if (json is String) {
      return WebSocketEvent.fromMap(jsonDecode(json));
    }
    return WebSocketEvent.fromMap(json as Map<String, dynamic>);
  }
}
