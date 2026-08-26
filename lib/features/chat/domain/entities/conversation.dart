class Conversation {
  final String id;
  final String? lastMessageText;
  final DateTime? lastMessageAt;
  final String? lastMessageSenderId;
  final int unreadCount;
  final bool isPinned;
  final bool isArchived;
  final bool isMuted;
  final DateTime? muteUntil;
  final String participantId;
  final String participantName;
  final String? participantAvatar;

  Conversation({
    required this.id,
    this.lastMessageText,
    this.lastMessageAt,
    this.lastMessageSenderId,
    this.unreadCount = 0,
    this.isPinned = false,
    this.isArchived = false,
    this.isMuted = false,
    this.muteUntil,
    required this.participantId,
    required this.participantName,
    this.participantAvatar,
  });

  Conversation copyWith({
    String? id,
    String? lastMessageText,
    DateTime? lastMessageAt,
    String? lastMessageSenderId,
    int? unreadCount,
    bool? isPinned,
    bool? isArchived,
    bool? isMuted,
    DateTime? muteUntil,
    String? participantId,
    String? participantName,
    String? participantAvatar,
  }) {
    return Conversation(
      id: id ?? this.id,
      lastMessageText: lastMessageText ?? this.lastMessageText,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      unreadCount: unreadCount ?? this.unreadCount,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      isMuted: isMuted ?? this.isMuted,
      muteUntil: muteUntil ?? this.muteUntil,
      participantId: participantId ?? this.participantId,
      participantName: participantName ?? this.participantName,
      participantAvatar: participantAvatar ?? this.participantAvatar,
    );
  }
}
