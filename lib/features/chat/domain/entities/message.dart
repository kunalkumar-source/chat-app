import 'chat_enums.dart';

class Message {
  final String? localId; // SQLite primary key
  final String clientMessageId; // UUID for idempotency
  final String? serverMessageId;
  final String conversationId;
  final String senderId;
  final String text;
  final DateTime createdAt; // Client time
  final DateTime? serverCreatedAt; // Server time
  final int? serverSequence; // Monotonically increasing sequence
  final SyncStatus syncStatus;
  final DeliveryStatus deliveryStatus;
  final MessageType type;
  final String? replyToMessageId;
  final bool isEdited;
  final DateTime? editedAt;
  final bool isDeleted;
  final DateTime? deletedAt;

  Message({
    this.localId,
    required this.clientMessageId,
    this.serverMessageId,
    required this.conversationId,
    required this.senderId,
    required this.text,
    required this.createdAt,
    this.serverCreatedAt,
    this.serverSequence,
    this.syncStatus = SyncStatus.pending,
    this.deliveryStatus = DeliveryStatus.sending,
    this.type = MessageType.text,
    this.replyToMessageId,
    this.isEdited = false,
    this.editedAt,
    this.isDeleted = false,
    this.deletedAt,
  });

  Message copyWith({
    String? localId,
    String? clientMessageId,
    String? serverMessageId,
    String? conversationId,
    String? senderId,
    String? text,
    DateTime? createdAt,
    DateTime? serverCreatedAt,
    int? serverSequence,
    SyncStatus? syncStatus,
    DeliveryStatus? deliveryStatus,
    MessageType? type,
    String? replyToMessageId,
    bool? isEdited,
    DateTime? editedAt,
    bool? isDeleted,
    DateTime? deletedAt,
  }) {
    return Message(
      localId: localId ?? this.localId,
      clientMessageId: clientMessageId ?? this.clientMessageId,
      serverMessageId: serverMessageId ?? this.serverMessageId,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      serverCreatedAt: serverCreatedAt ?? this.serverCreatedAt,
      serverSequence: serverSequence ?? this.serverSequence,
      syncStatus: syncStatus ?? this.syncStatus,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      type: type ?? this.type,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      isEdited: isEdited ?? this.isEdited,
      editedAt: editedAt ?? this.editedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}
