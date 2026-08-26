import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:testingfeature/core/theme/app_colors.dart';
import 'package:testingfeature/features/chat/domain/entities/chat_user.dart';
import 'package:testingfeature/core/widgets/typing_dots_indicator.dart';
import 'package:testingfeature/features/chat/domain/repositories/chat_repository.dart';
import '../providers/chat_providers.dart';
import '../widgets/hyy_empty_chat_view.dart';
import '../../domain/entities/message.dart';
import '../../domain/entities/chat_enums.dart';

class ChatDetailPage extends ConsumerStatefulWidget {
  final String conversationId;
  final ChatUser? participant;

  const ChatDetailPage({
    super.key,
    required this.conversationId,
    this.participant,
  });

  @override
  ConsumerState<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends ConsumerState<ChatDetailPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<Message> _searchResults = [];

  Timer? _typingTimer;
  bool _isTyping = false;
  int _currentOffset = 0;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  String get _receiverId {
    if (widget.participant?.id != null && widget.participant!.id.isNotEmpty) {
      return widget.participant!.id;
    }
    return '';
  }

  late final IChatRepository _chatRepo;
  String? _cachedCurrentUserId;
  String? _cachedReceiverId;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // Cache repo and user IDs safely before disposal
    _chatRepo = ref.read(chatRepositoryProvider);
    _cachedCurrentUserId = ref.read(currentUserProvider);
    _cachedReceiverId = widget.participant?.id;

    // Broadcast online status & notify server current chat screen is active (true)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_cachedCurrentUserId != null) {
        _chatRepo.setUserOnline(_cachedCurrentUserId!);

        if (_cachedReceiverId != null && _cachedReceiverId!.isNotEmpty) {
          _chatRepo.setCurrentChatUser(
            _cachedCurrentUserId!,
            _cachedReceiverId!,
            widget.conversationId,
            true,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    // Safely notify server current chat screen is closed using cached variables without calling ref
    if (_cachedCurrentUserId != null &&
        _cachedReceiverId != null &&
        _cachedReceiverId!.isNotEmpty) {
      _chatRepo.setCurrentChatUser(
        _cachedCurrentUserId!,
        _cachedReceiverId!,
        widget.conversationId,
        false,
      );
    }

    _messageController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    setState(() => _isLoadingMore = true);
    final nextOffset = _currentOffset + 50;
    final newMessages = await ref
        .read(chatRepositoryProvider)
        .loadMoreMessages(widget.conversationId, nextOffset);

    if (newMessages.isEmpty) {
      setState(() {
        _hasMore = false;
        _isLoadingMore = false;
      });
    } else {
      setState(() {
        _currentOffset = nextOffset;
        _isLoadingMore = false;
      });
    }
  }

  void _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    final results =
        await ref.read(chatRepositoryProvider).searchMessages(query);
    setState(() => _searchResults = results);
  }

  void _sendMessage() {
    // Stop typing when sending
    _stopTyping();
    final text = _messageController.text.trim();
    final currentUserId = ref.read(currentUserProvider);
    final receiverId = _receiverId;

    if (text.isNotEmpty && currentUserId != null) {
      ref.read(chatRepositoryProvider).sendMessage(
            widget.conversationId,
            currentUserId,
            receiverId,
            text,
          );
      _messageController.clear();
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }
  }

  void _onTyping(String value) {
    final receiverId = _receiverId;
    if (receiverId.isEmpty) return;

    if (!_isTyping) {
      _isTyping = true;
      ref.read(chatRepositoryProvider).setTypingStatus(
            widget.conversationId,
            receiverId,
            true,
          );
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      _stopTyping();
    });
  }

  void _stopTyping() {
    if (_isTyping) {
      _isTyping = false;
      final receiverId = _receiverId;
      if (receiverId.isNotEmpty) {
        ref.read(chatRepositoryProvider).setTypingStatus(
              widget.conversationId,
              receiverId,
              false,
            );
      }
    }
  }

  void _markAllAsRead() {
    final currentUserId = ref.read(currentUserProvider);
    final receiverId = _receiverId;

    ref.read(chatRepositoryProvider).markConversationAsRead(
          widget.conversationId,
          currentUserId: currentUserId,
          receiverId: receiverId,
        );
  }

  void _showActions(Message message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Material(
          color: Colors.transparent,
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.reply),
                title: const Text('Reply'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              if (message.senderId == ref.read(currentUserProvider)) ...[
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title:
                      const Text('Delete', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDelete(message);
                  },
                ),
              ],
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Copy Text'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(Message message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message?'),
        content: const Text('This will delete the message for everyone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showClearChatConfirmationDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.cleaning_services_rounded, color: Colors.redAccent),
            SizedBox(width: 10),
            Text(
              'Clear Chat?',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.redAccent,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete all messages in this chat with ${widget.participant?.name ?? 'this contact'}?\n\nThis will permanently delete messages from this device.',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await ref
                    .read(chatRepositoryProvider)
                    .clearConversationMessages(widget.conversationId);

                ref.invalidate(messagesProvider(widget.conversationId));
                ref.invalidate(conversationsProvider);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Chat messages cleared successfully.'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to clear chat: $e'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
            },
            child: const Text(
              'Clear Chat',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(messagesProvider(widget.conversationId));
    final currentUserId = ref.watch(currentUserProvider);

    final String displayName = widget.participant?.name ?? 'Chat';
    final String? avatarUrl = widget.participant?.avatarUrl;
    final String participantId = widget.participant?.id ?? '';

    final participantAsync = participantId.isNotEmpty
        ? ref.watch(userPresenceProvider(participantId))
        : const AsyncValue.loading();

    final isOnline = ref.watch(connectivityStatusProvider).value ?? true;

    final isTypingAsync = participantId.isNotEmpty
        ? ref.watch(userTypingStatusProvider(participantId))
        : const AsyncValue.data(false);

    return Scaffold(
      backgroundColor: AppColors.chatBackground,
      appBar: AppBar(
        backgroundColor: AppColors.appBarColor,
        foregroundColor: AppColors.appBarTitleColor,
        titleSpacing: 0,
        title: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: avatarUrl == null || avatarUrl.isEmpty
                      ? Text(
                          displayName.isNotEmpty
                              ? displayName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),
                participantAsync.maybeWhen(
                  data: (user) => Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 11,
                      height: 11,
                      decoration: BoxDecoration(
                        color: (user?.isOnline ?? false)
                            ? AppColors.onlineGreen
                            : AppColors.offlineGrey,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.appBarTitleColor,
                    ),
                  ),
                  participantAsync.when(
                    data: (user) {
                      if (user == null) return const SizedBox.shrink();
                      return Text(
                        user.isOnline ? 'Online' : 'Offline',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: Colors.white70,
                        ),
                      );
                    },
                    loading: () => const Text('...',
                        style: TextStyle(fontSize: 12, color: Colors.white70)),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search_rounded),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _searchResults.clear();
                }
              });
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            onSelected: (value) {
              if (value == 'clear_chat') {
                _showClearChatConfirmationDialog();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear_chat',
                child: Row(
                  children: [
                    Icon(Icons.cleaning_services_rounded,
                        color: Colors.redAccent, size: 20),
                    SizedBox(width: 10),
                    Text(
                      'Clear Chat',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (!isOnline)
            Container(
              width: double.infinity,
              color: Colors.amber.shade800,
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Offline Mode - Messages will send when connected',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          if (_isSearching)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search messages...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                ),
                onChanged: _performSearch,
              ),
            ),
          Expanded(
            child: _isSearching && _searchController.text.isNotEmpty
                ? ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final message = _searchResults[index];
                      return ListTile(
                        title: Text(message.text),
                        subtitle: Text(message.createdAt.toString()),
                        onTap: () {},
                      );
                    },
                  )
                : messagesAsync.when(
                    data: (messages) {
                      if (messages.isEmpty) {
                        return HyyEmptyChatView(
                          participantName: displayName,
                          onQuickSend: (quickMsg) {
                            _messageController.text = quickMsg;
                            _sendMessage();
                          },
                        );
                      }

                      final hasUnreadIncoming = messages.any((m) =>
                          m.senderId != currentUserId &&
                          m.deliveryStatus != DeliveryStatus.read);
                      if (hasUnreadIncoming) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            _markAllAsRead();
                          }
                        });
                      }

                      return ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 8),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          if (message.isDeleted) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.0),
                                child: Text(
                                  'This message was deleted',
                                  style: TextStyle(
                                    color: AppColors.textSubtle,
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            );
                          }
                          final isMe = message.senderId == currentUserId;
                          return GestureDetector(
                            onLongPress: () => _showActions(message),
                            child: _MessageBubble(message: message, isMe: isMe),
                          );
                        },
                      );
                    },
                    loading: () => const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary)),
                    error: (err, stack) => Center(child: Text('Error: $err')),
                  ),
          ),
          if (isTypingAsync.value ?? false)
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.only(left: 16, bottom: 8, top: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$displayName is typing',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const TypingDotsIndicator(
                      dotSize: 5.0,
                      dotColor: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, -2),
            blurRadius: 6,
            color: Colors.black.withValues(alpha: 0.04),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded,
                  color: AppColors.iconColor, size: 26),
              onPressed: () {},
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.inputBackground,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    hintText: 'Type a message',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: _onTyping,
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 6),
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.primary,
              child: IconButton(
                icon: const Icon(Icons.send_rounded,
                    color: Colors.white, size: 18),
                onPressed: _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;

  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color:
              isMe ? AppColors.myMessageBubble : AppColors.otherMessageBubble,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(isMe ? 12 : 2),
            bottomRight: Radius.circular(isMe ? 2 : 12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color:
                    isMe ? AppColors.myMessageText : AppColors.otherMessageText,
                fontSize: 15,
                height: 1.3,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${message.createdAt.hour}:${message.createdAt.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    color: AppColors.textSubtle,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  _buildStatusIcon(),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    IconData icon;
    Color color = AppColors.textSubtle;

    switch (message.syncStatus) {
      case SyncStatus.pending:
        icon = Icons.access_time_rounded;
        break;
      case SyncStatus.failed:
        icon = Icons.error_outline_rounded;
        color = Colors.redAccent;
        break;
      default:
        switch (message.deliveryStatus) {
          case DeliveryStatus.sent:
            icon = Icons.check_rounded;
            break;
          case DeliveryStatus.delivered:
            icon = Icons.done_all_rounded;
            break;
          case DeliveryStatus.read:
            icon = Icons.done_all_rounded;
            color = AppColors.readTickBlue;
            break;
          default:
            icon = Icons.check_rounded;
        }
    }

    return Icon(icon, size: 14, color: color);
  }
}
