import '../../domain/entities/conversation.dart';

class ConversationModel extends Conversation {
  ConversationModel({
    required super.id,
    super.lastMessageText,
    super.lastMessageAt,
    super.lastMessageSenderId,
    super.unreadCount,
    super.isPinned,
    super.isArchived,
    super.isMuted,
    super.muteUntil,
    required super.participantId,
    required super.participantName,
    super.participantAvatar,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'participantId': participantId,
      'lastMessageText': lastMessageText,
      'lastMessageAt': lastMessageAt?.millisecondsSinceEpoch,
      'lastMessageSenderId': lastMessageSenderId,
      'unreadCount': unreadCount,
    };
  }

  factory ConversationModel.fromMap(
      Map<String, dynamic> map,
      Map<String, dynamic>? settings,
      Map<String, dynamic> participant) {
    return ConversationModel(
      id: map['id'],
      lastMessageText: map['lastMessageText'],
      lastMessageAt: map['lastMessageAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastMessageAt'])
          : null,
      lastMessageSenderId: map['lastMessageSenderId'],
      unreadCount: map['unreadCount'] ?? 0,
      isPinned: settings?['isPinned'] == 1,
      isArchived: settings?['isArchived'] == 1,
      isMuted: settings?['isMuted'] == 1,
      muteUntil: settings?['muteUntil'] != null
          ? DateTime.fromMillisecondsSinceEpoch(settings!['muteUntil'])
          : null,
      participantId: participant['id'],
      participantName: participant['name'],
      participantAvatar: participant['avatarUrl'],
    );
  }
}
