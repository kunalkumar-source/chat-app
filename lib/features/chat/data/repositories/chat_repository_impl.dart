import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database_helper.dart';
import '../../../../core/network/api_service.dart';
import '../../../../core/network/socket_client.dart';
import '../../domain/entities/chat_enums.dart';
import '../../domain/entities/chat_user.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/message.dart';
import '../../domain/repositories/chat_repository.dart';
import '../models/chat_user_model.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';

/// Single, simplified repository implementation for Chat.
/// Manages SQLite local database, REST API, WebSockets, and Offline queueing.
class ChatRepositoryImpl implements IChatRepository {
  final DatabaseHelper _dbHelper;
  final ApiService _apiService;
  final SocketClient _socketClient;
  final _uuid = const Uuid();

  final _messagesUpdateController = StreamController<String>.broadcast();
  final _conversationsUpdateController = StreamController<void>.broadcast();
  final _userPresenceController = StreamController<String>.broadcast();
  final _typingStatusController =
      StreamController<Map<String, bool>>.broadcast();

  StreamSubscription? _connectivitySubscription;
  StreamSubscription? _socketStatusSubscription;
  bool _isProcessingOutbox = false;
  String? _activeUserId;
  final Map<String, bool> _presenceStateMap = {};

  ChatRepositoryImpl(
    this._dbHelper,
    this._apiService,
    this._socketClient,
  ) {
    _initListeners();
  }

  /// Initialize real-time network and socket listeners
  void _initListeners() {
    // 1. Listen for network connection changes
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) {
      final isOnline =
          results.any((result) => result != ConnectivityResult.none);
      if (isOnline) {
        debugPrint(
            '📡 [NETWORK] Device is back online. Registering presence & flushing queue...');
        if (_activeUserId != null && _activeUserId!.isNotEmpty) {
          setUserOnline(_activeUserId!);
        }
        processPendingOutbox();
      }
    });

    // 2. Listen for socket status changes
    _socketStatusSubscription = _socketClient.status.listen((status) {
      if (status == SocketStatus.connected) {
        debugPrint('🌐 [SOCKET] Connected. Registering user online status...');
        if (_activeUserId != null && _activeUserId!.isNotEmpty) {
          debugPrint(
              '🟢 [SOCKET PRESENCE] Emitting register & user_online for: $_activeUserId');
          _socketClient.emit('register', _activeUserId);
          _socketClient.emit('user_online', _activeUserId);
        }
        processPendingOutbox();
      }
    });

    // 3. Listen for incoming WebSocket messages & presence events
    _socketClient.on('new_message', (data) {
      debugPrint('📥 [SOCKET INCOMING] Event: [new_message] Data: $data');
      _handleIncomingSocketMessage(data);
    });
    _socketClient.on('user_online', (data) {
      debugPrint('📥 [SOCKET INCOMING] Event: [user_online] Data: $data');
      _handlePresenceEvent(data, true);
    });
    _socketClient.on('user_offline', (data) {
      debugPrint('📥 [SOCKET INCOMING] Event: [user_offline] Data: $data');
      _handlePresenceEvent(data, false);
    });
    _socketClient.on('message_read', (data) {
      debugPrint('📥 [SOCKET INCOMING] Event: [message_read] Data: $data');
      _handleMessageRead(data);
    });
    _socketClient.on('message_delivered', (data) {
      debugPrint('📥 [SOCKET INCOMING] Event: [message_delivered] Data: $data');
      _handleMessageStatusUpdate(data, DeliveryStatus.delivered);
    });
    _socketClient.on('message_status', (data) {
      debugPrint('📥 [SOCKET INCOMING] Event: [message_status] Data: $data');
      _handleMessageStatusUpdate(data, null);
    });
    _socketClient.on('typing', (data) {
      debugPrint('📥 [SOCKET INCOMING] Event: [typing] Data: $data');
      _handleTypingEvent(data, true);
    });
    _socketClient.on('stop_typing', (data) {
      debugPrint('📥 [SOCKET INCOMING] Event: [stop_typing] Data: $data');
      _handleTypingEvent(data, false);
    });
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _socketStatusSubscription?.cancel();
    _messagesUpdateController.close();
    _conversationsUpdateController.close();
    _userPresenceController.close();
    _typingStatusController.close();
  }

  // ===========================================================================
  // USERS & PRESENCE
  // ===========================================================================

  @override
  Future<List<ChatUser>> getAllUsers() async {
    try {
      // 1. Fetch fresh users from backend API
      final users = await _apiService.getAllUsers();
      final db = await _dbHelper.database;

      // Read current presence states from SQLite to prevent overwriting live online statuses
      final existingUsers =
          await db.query('chat_users', columns: ['id', 'isOnline']);
      final onlineMap = <String, bool>{};
      for (var row in existingUsers) {
        if (row['isOnline'] == 1) {
          onlineMap[row['id'].toString()] = true;
        }
      }

      // 2. Cache users in local SQLite database (PRESERVING active presence states)
      final batch = db.batch();
      final updatedUsers = <ChatUser>[];
      for (var user in users) {
        final isOnline =
            _presenceStateMap[user.id] ?? onlineMap[user.id] ?? user.isOnline;
        final updatedUser = user.copyWith(isOnline: isOnline);
        updatedUsers.add(updatedUser);

        final map = user.toMap();
        map['isOnline'] = isOnline ? 1 : 0;
        batch.insert('chat_users', map,
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);

      // 3. Trigger online presence event AFTER users API success response
      if (_activeUserId != null && _activeUserId!.isNotEmpty) {
        debugPrint(
            '🟢 [USERS API SUCCESS] Triggering register & user_online for: $_activeUserId');
        setUserOnline(_activeUserId!);
      }

      return updatedUsers;
    } catch (e) {
      debugPrint(
          '⚠️ [CHAT REPO] API user fetch failed, loading from local DB: $e');
      final db = await _dbHelper.database;
      final maps = await db.query('chat_users');
      return maps.map((m) {
        final u = ChatUserModel.fromMap(m);
        final isOnline = _presenceStateMap[u.id] ?? u.isOnline;
        return u.copyWith(isOnline: isOnline);
      }).toList();
    }
  }

  @override
  Future<ChatUser?> getParticipant(String userId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'chat_users',
      where: 'id = ?',
      whereArgs: [userId],
    );
    if (maps.isEmpty) {
      if (_presenceStateMap.containsKey(userId)) {
        return ChatUser(
          id: userId,
          name:
              'User ${userId.substring(0, userId.length > 6 ? 6 : userId.length)}',
          isOnline: _presenceStateMap[userId] ?? false,
        );
      }
      return null;
    }
    final user = ChatUserModel.fromMap(maps.first);
    final isOnline = _presenceStateMap[userId] ?? user.isOnline;
    return user.copyWith(isOnline: isOnline);
  }

  Stream<String> get userPresenceStream => _userPresenceController.stream;

  // ===========================================================================
  // CONVERSATIONS
  // ===========================================================================

  @override
  Stream<List<Conversation>> watchConversations() async* {
    yield await getConversations();
    await for (final _ in _conversationsUpdateController.stream) {
      yield await getConversations();
    }
  }

  @override
  Future<List<Conversation>> getConversations() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT c.*, u.name as participantName, u.avatarUrl as participantAvatar
      FROM conversations c
      LEFT JOIN chat_users u ON c.participantId = u.id
      ORDER BY c.lastMessageAt DESC
    ''');

    return maps.map((map) {
      final participant = {
        'id': map['participantId'],
        'name': map['participantName'] ?? 'Chat User',
        'avatarUrl': map['participantAvatar'],
      };
      return ConversationModel.fromMap(map, null, participant);
    }).toList();
  }

  @override
  Future<String> getOrCreateConversation(
      String currentUserId, String participantId) async {
    // Generate deterministic conversation ID: currentUser_receiverId (sorted)
    final conversationId =
        IChatRepository.getConversationId(currentUserId, participantId);
    final db = await _dbHelper.database;

    final existing = await db.query(
      'conversations',
      where: 'id = ?',
      whereArgs: [conversationId],
    );

    if (existing.isEmpty) {
      await db.insert(
        'conversations',
        {
          'id': conversationId,
          'participantId': participantId,
          'lastMessageText': null,
          'lastMessageAt': DateTime.now().millisecondsSinceEpoch,
          'lastMessageSenderId': null,
          'unreadCount': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      _conversationsUpdateController.add(null);
    }

    return conversationId;
  }

  // ===========================================================================
  // MESSAGES
  // ===========================================================================

  @override
  Stream<List<Message>> watchMessages(String conversationId) async* {
    yield await getMessages(conversationId);
    await for (final updatedId in _messagesUpdateController.stream) {
      if (updatedId.isEmpty || updatedId == conversationId) {
        yield await getMessages(conversationId);
      }
    }
  }

  @override
  Future<List<Message>> loadMoreMessages(String conversationId, int offset,
      {int limit = 50}) async {
    return getMessages(conversationId, limit: limit, offset: offset);
  }

  @override
  Future<List<Message>> getMessages(
    String conversationId, {
    int limit = 50,
    int? offset,
    int? beforeSequence,
  }) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      'messages',
      where: 'conversationId = ?',
      whereArgs: [conversationId],
      orderBy: 'createdAt DESC',
      limit: limit,
      offset: offset,
    );

    return maps.map((map) => MessageModel.fromMap(map)).toList();
  }

  @override
  Future<List<Message>> searchMessages(String query) async {
    if (query.trim().isEmpty) return [];
    final db = await _dbHelper.database;
    final maps = await db.query(
      'messages',
      where: 'text LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'createdAt DESC',
    );
    return maps.map((map) => MessageModel.fromMap(map)).toList();
  }

  @override
  Future<void> sendMessage(
    String conversationId,
    String senderId,
    String receiverId,
    String text,
  ) async {
    final clientMessageId = _uuid.v4();
    final now = DateTime.now();

    final message = MessageModel(
      clientMessageId: clientMessageId,
      conversationId: conversationId,
      senderId: senderId,
      text: text,
      createdAt: now,
      syncStatus: SyncStatus.pending,
      deliveryStatus: DeliveryStatus.sending,
    );

    final db = await _dbHelper.database;

    // 1. Save message to local SQLite database immediately
    await db.insert('messages', message.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);

    // 2. Add message payload to local outbox queue
    final payloadMap = {
      'clientMessageId': clientMessageId,
      'conversationId': conversationId,
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
      'createdAt': now.millisecondsSinceEpoch,
    };

    debugPrint(
        '💬 [SEND MESSAGE] Prepared message data before sending: ${const JsonEncoder.withIndent('  ').convert(payloadMap)}');

    final payload = jsonEncode(payloadMap);

    await db.insert('message_outbox', {
      'operation': 'sendMessage',
      'entityId': clientMessageId,
      'payload': payload,
      'status': OutboxStatus.pending.name,
      'createdAt': now.millisecondsSinceEpoch,
    });

    // 3. Update conversation last message summary locally
    await db.update(
      'conversations',
      {
        'lastMessageText': text,
        'lastMessageAt': now.millisecondsSinceEpoch,
        'lastMessageSenderId': senderId,
      },
      where: 'id = ?',
      whereArgs: [conversationId],
    );

    // 4. Notify UI components to render the message instantly
    _messagesUpdateController.add(conversationId);
    _conversationsUpdateController.add(null);

    // 5. Attempt to process outbox immediately if online
    processPendingOutbox();
  }

  @override
  Future<void> markConversationAsRead(String conversationId,
      {String? currentUserId, String? receiverId}) async {
    final db = await _dbHelper.database;

    // 1. Fetch unread message IDs to send exact message IDs if present
    final unreadMaps = await db.query(
      'messages',
      columns: ['serverMessageId', 'clientMessageId', 'senderId'],
      where: 'conversationId = ? AND deliveryStatus != ?',
      whereArgs: [conversationId, DeliveryStatus.read.name],
    );

    // 2. Update all messages in this conversation to 'read' if they are from other users
    await db.update(
      'messages',
      {
        'deliveryStatus': DeliveryStatus.read.name,
        'syncStatus': SyncStatus.synced.name
      },
      where: 'conversationId = ? AND deliveryStatus != ?',
      whereArgs: [conversationId, DeliveryStatus.read.name],
    );

    // 3. Reset unreadCount for the conversation
    await db.update(
      'conversations',
      {'unreadCount': 0},
      where: 'id = ?',
      whereArgs: [conversationId],
    );

    // 4. Notify server via socket using message_read event with exact payload structure
    if (_socketClient.isConnected) {
      final msgId = unreadMaps.isNotEmpty
          ? (unreadMaps.last['serverMessageId'] ??
              unreadMaps.last['clientMessageId'])
          : null;
      final originalSender = unreadMaps.isNotEmpty
          ? unreadMaps.last['senderId']?.toString()
          : receiverId;

      _socketClient.emit('message_read', {
        'messageId': msgId ?? conversationId,
        'senderId': originalSender ?? receiverId ?? '',
        'receiverId': currentUserId ?? '',
        'conversationId': conversationId,
      });
    }

    _messagesUpdateController.add(conversationId);
    _conversationsUpdateController.add(null);
  }

  @override
  Future<void> markAsRead(
      String conversationId, String messageId, String senderId) async {
    final db = await _dbHelper.database;
    await db.update(
      'messages',
      {
        'deliveryStatus': DeliveryStatus.read.name,
        'syncStatus': SyncStatus.synced.name
      },
      where: 'clientMessageId = ? OR serverMessageId = ?',
      whereArgs: [messageId, messageId],
    );

    // Reset unreadCount for the conversation
    await db.update(
      'conversations',
      {'unreadCount': 0},
      where: 'id = ?',
      whereArgs: [conversationId],
    );

    if (_socketClient.isConnected) {
      // Updated to match implementation guide: event name 'message_read'
      _socketClient.emit('message_read', {
        'messageId': messageId,
        'conversationId': conversationId,
        'senderId': senderId,
        'receiverId':
            senderId, // In this context, we are the receiver marking it read
      });
    }

    _messagesUpdateController.add(conversationId);
    _conversationsUpdateController.add(null);
  }

  // ===========================================================================
  // OFFLINE QUEUE & SYNC
  // ===========================================================================

  /// Flushes pending messages from local SQLite outbox to server
  Future<void> processPendingOutbox() async {
    if (_isProcessingOutbox) return;
    _isProcessingOutbox = true;

    try {
      final db = await _dbHelper.database;
      final pendingItems = await db.query(
        'message_outbox',
        where: 'status = ?',
        whereArgs: [OutboxStatus.pending.name],
        orderBy: 'createdAt ASC',
      );

      for (var item in pendingItems) {
        final id = item['id'] as int;
        final payloadStr = item['payload'] as String;
        final data = jsonDecode(payloadStr) as Map<String, dynamic>;

        final clientMessageId = data['clientMessageId'] as String;
        final conversationId = data['conversationId'] as String;

        if (_socketClient.isConnected) {
          debugPrint(
              '📤 [SEND MESSAGE EVENT] Emitting send_message event with data:\n${const JsonEncoder.withIndent('  ').convert(data)}');
          _socketClient.emit('send_message', data);

          // Update local status to synced & sent
          await db.update(
            'messages',
            {
              'syncStatus': SyncStatus.synced.name,
              'deliveryStatus': DeliveryStatus.sent.name,
            },
            where: 'clientMessageId = ?',
            whereArgs: [clientMessageId],
          );

          // Remove item from outbox queue
          await db.delete('message_outbox', where: 'id = ?', whereArgs: [id]);
          _messagesUpdateController.add(conversationId);
        } else {
          // Socket not connected, keep in outbox for next attempt
          break;
        }
      }
    } catch (e) {
      debugPrint('⚠️ [OUTBOX] Error processing outbox: $e');
      // Update failing items to failed status after some retries could be added here
      if (e is Exception) {
        // Mark as failed if we hit a persistent error
        final db = await _dbHelper.database;
        await db.update('message_outbox', {'status': 'failed'},
            where: 'status = ?', whereArgs: ['pending']);
        await db.update('messages', {'syncStatus': SyncStatus.failed.name},
            where: 'syncStatus = ?', whereArgs: [SyncStatus.pending.name]);
      }
    } finally {
      _isProcessingOutbox = false;
    }
  }

  @override
  Future<void> retryFailedMessages() async {
    final db = await _dbHelper.database;
    await db.update(
      'message_outbox',
      {'status': OutboxStatus.pending.name},
      where: 'status = ?',
      whereArgs: ['failed'],
    );
    await db.update(
      'messages',
      {'syncStatus': SyncStatus.pending.name},
      where: 'syncStatus = ?',
      whereArgs: [SyncStatus.failed.name],
    );
    processPendingOutbox();
  }

  // ===========================================================================
  // SOCKET EVENT HANDLERS
  // ===========================================================================

  Future<void> _handleIncomingSocketMessage(dynamic data) async {
    if (data is! Map) return;
    final map = Map<String, dynamic>.from(data);
    final conversationId = map['conversationId']?.toString() ?? '';
    final text = map['text']?.toString() ?? '';
    final senderId = map['senderId']?.toString() ?? '';

    final db = await _dbHelper.database;
    final model = MessageModel.fromJson(map);

    await db.insert('messages', model.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);

    // Update conversation summary and increment unread count
    await db.rawUpdate('''
      UPDATE conversations 
      SET lastMessageText = ?, 
          lastMessageAt = ?, 
          lastMessageSenderId = ?, 
          unreadCount = unreadCount + 1 
      WHERE id = ?
    ''', [
      text,
      DateTime.now().millisecondsSinceEpoch,
      senderId,
      conversationId
    ]);

    _messagesUpdateController.add(conversationId);
    _conversationsUpdateController.add(null);
  }

  Future<void> _handleTypingEvent(dynamic data, bool isTyping) async {
    if (data is! Map) return;
    final userId = data['senderId']?.toString() ??
        data['userId']?.toString() ??
        data['id']?.toString();
    if (userId != null && userId.isNotEmpty) {
      _typingStatusController.add({userId: isTyping});
    }
  }

  @override
  Future<void> setTypingStatus(
      String conversationId, String receiverId, bool isTyping) async {
    if (_socketClient.isConnected) {
      final event = isTyping ? 'typing' : 'stop_typing';
      _socketClient.emit(event, {
        'conversationId': conversationId,
        'receiverId': receiverId,
      });
    }
  }

  @override
  Stream<bool> watchTypingStatus(String userId) {
    return _typingStatusController.stream
        .where((event) => event.containsKey(userId))
        .map((event) => event[userId]!);
  }

  Future<void> _handlePresenceEvent(dynamic data, bool isOnline) async {
    String? userId;
    if (data is Map) {
      userId = data['userId']?.toString() ?? data['id']?.toString();
    } else if (data is String) {
      userId = data;
    }

    if (userId != null && userId.isNotEmpty) {
      // Deduplicate: If user presence state is already identical, do not re-process
      if (_presenceStateMap[userId] == isOnline) {
        return;
      }
      _presenceStateMap[userId] = isOnline;

      final db = await _dbHelper.database;

      final count = await db.update(
        'chat_users',
        {
          'isOnline': isOnline ? 1 : 0,
          'lastSeen': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [userId],
      );

      if (count == 0) {
        // If user wasn't in SQLite yet, insert basic user entry so presence is tracked
        await db.insert(
          'chat_users',
          {
            'id': userId,
            'name':
                'User ${userId.substring(0, userId.length > 6 ? 6 : userId.length)}',
            'isOnline': isOnline ? 1 : 0,
            'lastSeen': DateTime.now().millisecondsSinceEpoch,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      debugPrint(
          '🟢 [PRESENCE] User $userId is now ${isOnline ? 'ONLINE' : 'OFFLINE'}');
      _userPresenceController.add(userId);
      _conversationsUpdateController.add(null);
    }
  }

  @override
  Future<void> setUserOnline(String userId) async {
    if (userId.isEmpty) return;
    _activeUserId = userId;

    if (_socketClient.isConnected) {
      debugPrint(
          '🌐 [SOCKET] Registering user presence & online event for: $userId');
      _socketClient.emit('register', userId);
      _socketClient.emit('user_online', userId);
    }
  }

  @override
  Future<void> setUserOffline(String userId) async {
    if (userId.isEmpty) return;
    if (_socketClient.isConnected) {
      debugPrint('🔴 [SOCKET] Emitting user offline presence for: $userId');
      _socketClient.emit('user_offline', userId);
    }
    if (_activeUserId == userId) {
      _activeUserId = null;
    }
  }

  @override
  Future<void> setCurrentChatUser(String senderId, String receiverId,
      String conversationId, bool isChatOpen) async {
    if (_socketClient.isConnected &&
        senderId.isNotEmpty &&
        receiverId.isNotEmpty) {
      _socketClient.emit('current_chat_user', {
        'senderId': senderId,
        'receiverId': receiverId,
        'conversationId': conversationId,
        'isChatOpen': isChatOpen,
      });
    }
  }

  @override
  Stream<ChatUser?> watchUserPresence(String userId) async* {
    yield await getParticipant(userId);
    await for (final updatedUserId in _userPresenceController.stream) {
      if (updatedUserId == userId) {
        yield await getParticipant(userId);
      }
    }
  }

  Future<void> _handleMessageRead(dynamic data) async {
    if (data is! Map) return;
    final messageId = data['messageId']?.toString();
    final conversationId = data['conversationId']?.toString();

    final db = await _dbHelper.database;

    if (messageId != null && messageId.isNotEmpty) {
      await db.update(
        'messages',
        {
          'deliveryStatus': DeliveryStatus.read.name,
          'syncStatus': SyncStatus.synced.name
        },
        where: 'clientMessageId = ? OR serverMessageId = ? OR localId = ?',
        whereArgs: [messageId, messageId, messageId],
      );
    }

    if (conversationId != null && conversationId.isNotEmpty) {
      await db.update(
        'messages',
        {
          'deliveryStatus': DeliveryStatus.read.name,
          'syncStatus': SyncStatus.synced.name
        },
        where: 'conversationId = ?',
        whereArgs: [conversationId],
      );

      await db.update(
        'conversations',
        {'unreadCount': 0},
        where: 'id = ?',
        whereArgs: [conversationId],
      );

      _messagesUpdateController.add(conversationId);
      _conversationsUpdateController.add(null);
    } else {
      _conversationsUpdateController.add(null);
    }
  }

  Future<void> _handleMessageStatusUpdate(
      dynamic data, DeliveryStatus? fixedStatus) async {
    if (data is! Map) return;
    final messageId = data['messageId']?.toString();
    final statusStr = data['status']?.toString();

    DeliveryStatus status = fixedStatus ?? DeliveryStatus.sent;
    if (fixedStatus == null && statusStr != null) {
      if (statusStr == 'read') status = DeliveryStatus.read;
      if (statusStr == 'delivered') status = DeliveryStatus.delivered;
    }

    if (messageId != null) {
      final db = await _dbHelper.database;
      await db.update(
        'messages',
        {'deliveryStatus': status.name},
        where: 'clientMessageId = ? OR serverMessageId = ?',
        whereArgs: [messageId, messageId],
      );
      _conversationsUpdateController.add(null);
    }
  }

  // ===========================================================================
  // LOCAL CHAT BACKUP & RESTORE
  // ===========================================================================

  @override
  Future<String> exportChatBackup(String userId) async {
    final db = await _dbHelper.database;

    // 1. Query all local chat data from SQLite
    final users = await db.query('chat_users');
    final conversations = await db.query('conversations');
    final messages = await db.query('messages');

    // 2. Format backup JSON structure
    final backupData = {
      'version': 1,
      'userId': userId,
      'exportedAt': DateTime.now().toIso8601String(),
      'chat_users': users,
      'conversations': conversations,
      'messages': messages,
    };

    // 3. Save file into application documents directory under ChatBackups
    final docsDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory(p.join(docsDir.path, 'ChatBackups'));
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }

    final filePath = p.join(backupDir.path, 'chat_backup_$userId.json');
    final file = File(filePath);
    await file.writeAsString(jsonEncode(backupData));

    debugPrint('📦 [CHAT BACKUP] Successfully exported backup to: $filePath');
    return filePath;
  }

  @override
  Future<String?> getAutoBackupFilePath(String userId) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final filePath = p.join(docsDir.path, 'ChatBackups', 'chat_backup_$userId.json');
    final file = File(filePath);
    if (await file.exists()) {
      return filePath;
    }
    return null;
  }

  @override
  Future<int> importChatBackup(String filePath, String currentUserId) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('Backup file does not exist at: $filePath');
    }

    final content = await file.readAsString();
    final Map<String, dynamic> backupData = jsonDecode(content);

    // Validate account matching requirement
    final backupUserId = backupData['userId']?.toString();
    if (backupUserId != null &&
        backupUserId.isNotEmpty &&
        backupUserId != currentUserId) {
      throw Exception(
          'Account Mismatch: This backup file belongs to user account ID ($backupUserId). Please log in with that user account to restore this chat backup.');
    }

    final db = await _dbHelper.database;
    final batch = db.batch();

    // Import Chat Users
    final List<dynamic> users = backupData['chat_users'] ?? [];
    for (var u in users) {
      if (u is Map<String, dynamic>) {
        batch.insert('chat_users', u,
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }

    // Import Conversations
    final List<dynamic> conversations = backupData['conversations'] ?? [];
    for (var c in conversations) {
      if (c is Map<String, dynamic>) {
        batch.insert('conversations', c,
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    }

    // Import Messages
    final List<dynamic> messages = backupData['messages'] ?? [];
    int importedCount = 0;
    for (var m in messages) {
      if (m is Map<String, dynamic>) {
        batch.insert('messages', m,
            conflictAlgorithm: ConflictAlgorithm.replace);
        importedCount++;
      }
    }

    await batch.commit(noResult: true);

    // Refresh UI Controllers
    _presenceStateMap.clear();
    _conversationsUpdateController.add(null);
    _messagesUpdateController.add('');
    _userPresenceController.add('');

    debugPrint(
        '📥 [CHAT BACKUP] Successfully restored $importedCount messages from backup!');
    return importedCount;
  }

  @override
  Future<void> clearAllChats() async {
    final db = await _dbHelper.database;
    await db.delete('messages');
    await db.delete('conversations');
    await db.delete('message_outbox');
    _presenceStateMap.clear();

    _conversationsUpdateController.add(null);
    _messagesUpdateController.add('');
    _userPresenceController.add('');
    debugPrint('🗑️ [CHAT REPO] Cleared all local chats, messages, and outbox.');
  }

  @override
  Future<void> clearConversationMessages(String conversationId) async {
    if (conversationId.isEmpty) return;
    final db = await _dbHelper.database;
    await db.delete('messages', where: 'conversationId = ?', whereArgs: [conversationId]);
    await db.update(
      'conversations',
      {
        'lastMessageText': null,
        'lastMessageAt': null,
        'lastMessageSenderId': null,
        'unreadCount': 0,
      },
      where: 'id = ?',
      whereArgs: [conversationId],
    );

    _messagesUpdateController.add(conversationId);
    _conversationsUpdateController.add(null);
    debugPrint('🧹 [CHAT REPO] Cleared all messages for conversation: $conversationId');
  }
}
