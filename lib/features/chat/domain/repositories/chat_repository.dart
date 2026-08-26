import '../entities/message.dart';
import '../entities/conversation.dart';
import '../entities/chat_user.dart';

abstract class IChatRepository {
  /// Generates deterministic conversation ID for 1-on-1 chats: currentUser_receiverId (sorted)
  static String getConversationId(String currentUserId, String receiverId) {
    if (currentUserId.isEmpty || receiverId.isEmpty) {
      return currentUserId.isNotEmpty ? currentUserId : receiverId;
    }
    final ids = [currentUserId, receiverId]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  // Messages
  Stream<List<Message>> watchMessages(String conversationId);
  Future<List<Message>> getMessages(String conversationId,
      {int limit = 50, int? offset, int? beforeSequence});
  Future<List<Message>> loadMoreMessages(String conversationId, int offset,
      {int limit = 50});
  Future<List<Message>> searchMessages(String query);
  Future<void> sendMessage(
      String conversationId, String senderId, String receiverId, String text);
  Future<void> markAsRead(
      String conversationId, String messageId, String senderId);
  Future<void> markConversationAsRead(String conversationId,
      {String? currentUserId, String? receiverId});

  // Conversations
  Stream<List<Conversation>> watchConversations();
  Future<List<Conversation>> getConversations();
  Future<String> getOrCreateConversation(
      String currentUserId, String participantId);

  // User Actions
  Future<List<ChatUser>> getAllUsers();
  Future<ChatUser?> getParticipant(String userId);
  Stream<ChatUser?> watchUserPresence(String userId);
  Future<void> setUserOnline(String userId);
  Future<void> setUserOffline(String userId);

  // Typing
  Stream<bool> watchTypingStatus(String userId);
  Future<void> setTypingStatus(
      String conversationId, String receiverId, bool isTyping);

  // Screen Focus Tracking
  Future<void> setCurrentChatUser(String senderId, String receiverId,
      String conversationId, bool isChatOpen);

  // Sync & Backup
  Future<void> retryFailedMessages();
  Future<String> exportChatBackup(String userId);
  Future<String?> getAutoBackupFilePath(String userId);
  Future<int> importChatBackup(String filePath, String currentUserId);
  Future<void> clearAllChats();
  Future<void> clearConversationMessages(String conversationId);
}
