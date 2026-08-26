import 'message_model.dart';
import 'chat_user_model.dart';

class SyncResponse {
  final List<MessageModel> messages;
  final List<ChatUserModel> users;
  final String? nextCursor;
  final bool hasMore;

  SyncResponse({
    required this.messages,
    required this.users,
    this.nextCursor,
    this.hasMore = false,
  });

  factory SyncResponse.fromJson(Map<String, dynamic> json) {
    return SyncResponse(
      messages: (json['messages'] as List? ?? [])
          .map((m) => MessageModel.fromJson(m))
          .toList(),
      users: (json['users'] as List? ?? [])
          .map((u) => ChatUserModel.fromJson(u))
          .toList(),
      nextCursor: json['nextCursor'],
      hasMore: json['hasMore'] ?? false,
    );
  }
}
