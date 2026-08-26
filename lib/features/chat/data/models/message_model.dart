import '../../domain/entities/chat_enums.dart';
import '../../domain/entities/message.dart';

class MessageModel extends Message {
  MessageModel({
    super.localId,
    required super.clientMessageId,
    super.serverMessageId,
    required super.conversationId,
    required super.senderId,
    required super.text,
    required super.createdAt,
    super.serverCreatedAt,
    super.serverSequence,
    super.syncStatus,
    super.deliveryStatus,
    super.type,
    super.replyToMessageId,
    super.isEdited,
    super.editedAt,
    super.isDeleted,
    super.deletedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'localId': localId,
      'clientMessageId': clientMessageId,
      'serverMessageId': serverMessageId,
      'conversationId': conversationId,
      'senderId': senderId,
      'text': text,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'serverCreatedAt': serverCreatedAt?.millisecondsSinceEpoch,
      'serverSequence': serverSequence,
      'syncStatus': syncStatus.name,
      'deliveryStatus': deliveryStatus.name,
      'type': type.name,
      'replyToMessageId': replyToMessageId,
      'isEdited': isEdited ? 1 : 0,
      'editedAt': editedAt?.millisecondsSinceEpoch,
      'isDeleted': isDeleted ? 1 : 0,
      'deletedAt': deletedAt?.millisecondsSinceEpoch,
    };
  }

  Map<String, dynamic> toJson() => toMap();

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
      final asInt = int.tryParse(value);
      if (asInt != null) return DateTime.fromMillisecondsSinceEpoch(asInt);
    }
    if (value is DateTime) return value;
    return DateTime.now();
  }

  static DateTime? _parseNullableDateTime(dynamic value) {
    if (value == null) return null;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
      final asInt = int.tryParse(value);
      if (asInt != null) return DateTime.fromMillisecondsSinceEpoch(asInt);
    }
    if (value is DateTime) return value;
    return null;
  }

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    final msgId = (map['messageId'] ?? map['serverMessageId'] ?? map['id'])?.toString();
    final clientMsgId = (map['clientMessageId'] ?? msgId ?? DateTime.now().millisecondsSinceEpoch.toString()).toString();

    return MessageModel(
      localId: map['localId']?.toString(),
      clientMessageId: clientMsgId,
      serverMessageId: map['serverMessageId']?.toString() ?? msgId,
      conversationId: map['conversationId']?.toString() ?? '',
      senderId: map['senderId']?.toString() ?? '',
      text: map['text']?.toString() ?? '',
      createdAt: _parseDateTime(map['createdAt']),
      serverCreatedAt: _parseNullableDateTime(map['serverCreatedAt']),
      serverSequence: map['serverSequence'] is int ? map['serverSequence'] : int.tryParse(map['serverSequence']?.toString() ?? ''),
      syncStatus: map['syncStatus'] != null 
          ? SyncStatus.values.byName(map['syncStatus'].toString()) 
          : SyncStatus.synced,
      deliveryStatus: map['deliveryStatus'] != null 
          ? DeliveryStatus.values.byName(map['deliveryStatus'].toString()) 
          : DeliveryStatus.sent,
      type: MessageType.values.byName(map['type']?.toString() ?? 'text'),
      replyToMessageId: map['replyToMessageId']?.toString(),
      isEdited: map['isEdited'] == 1 || map['isEdited'] == true,
      editedAt: _parseNullableDateTime(map['editedAt']),
      isDeleted: map['isDeleted'] == 1 || map['isDeleted'] == true,
      deletedAt: _parseNullableDateTime(map['deletedAt']),
    );
  }

  factory MessageModel.fromJson(Map<String, dynamic> json) => MessageModel.fromMap(json);

  factory MessageModel.fromEntity(Message entity) {
    return MessageModel(
      localId: entity.localId,
      clientMessageId: entity.clientMessageId,
      serverMessageId: entity.serverMessageId,
      conversationId: entity.conversationId,
      senderId: entity.senderId,
      text: entity.text,
      createdAt: entity.createdAt,
      serverCreatedAt: entity.serverCreatedAt,
      serverSequence: entity.serverSequence,
      syncStatus: entity.syncStatus,
      deliveryStatus: entity.deliveryStatus,
      type: entity.type,
      replyToMessageId: entity.replyToMessageId,
      isEdited: entity.isEdited,
      editedAt: entity.editedAt,
      isDeleted: entity.isDeleted,
      deletedAt: entity.deletedAt,
    );
  }
}
