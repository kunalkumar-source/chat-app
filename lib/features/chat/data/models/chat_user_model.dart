import '../../domain/entities/chat_user.dart';

class ChatUserModel extends ChatUser {
  ChatUserModel({
    required super.id,
    required super.name,
    super.avatarUrl,
    super.isOnline,
    super.lastSeen,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'avatarUrl': avatarUrl,
      'isOnline': isOnline ? 1 : 0,
      'lastSeen': lastSeen?.millisecondsSinceEpoch,
    };
  }

  Map<String, dynamic> toJson() => toMap();

  factory ChatUserModel.fromMap(Map<String, dynamic> map) {
    return ChatUserModel(
      id: map['id'] ?? map['_id'] ?? '',
      name: map['name'] ?? map['username'] ?? '',
      avatarUrl: map['avatarUrl'],
      isOnline: map['isOnline'] == 1 || map['isOnline'] == true,
      lastSeen: map['lastSeen'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['lastSeen']) 
          : null,
    );
  }

  factory ChatUserModel.fromJson(Map<String, dynamic> json) => ChatUserModel.fromMap(json);

  factory ChatUserModel.fromEntity(ChatUser entity) {
    return ChatUserModel(
      id: entity.id,
      name: entity.name,
      avatarUrl: entity.avatarUrl,
      isOnline: entity.isOnline,
      lastSeen: entity.lastSeen,
    );
  }
}
