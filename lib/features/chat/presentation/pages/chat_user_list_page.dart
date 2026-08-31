import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:testingfeature/core/theme/app_colors.dart';
import 'package:testingfeature/core/utils/date_formatter.dart';
import 'package:testingfeature/features/auth/presentation/providers/auth_providers.dart';
import 'package:testingfeature/features/chat/domain/entities/conversation.dart';
import 'package:testingfeature/features/chat/domain/repositories/chat_repository.dart';
import 'package:testingfeature/features/chat/presentation/pages/all_user_list_page.dart';
import 'package:testingfeature/features/settings/presentation/pages/settings_page.dart';
import '../providers/chat_providers.dart';
import 'chat_detail_page.dart';

class UserListPage extends ConsumerStatefulWidget {
  const UserListPage({super.key});

  @override
  ConsumerState<UserListPage> createState() => _UserListPageState();
}

class _UserListPageState extends ConsumerState<UserListPage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Broadcast online status when user arrives on Home / User List screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notifyOnlineStatus();
    });
  }

  @override
  void dispose() {
    // Notify server offline status when home page is destroyed or logged out
    _notifyOfflineStatus();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      debugPrint('📲 [APP LIFECYCLE] App resumed -> Sending Online event');
      _notifyOnlineStatus();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.inactive) {
      debugPrint(
          '📲 [APP LIFECYCLE] App backgrounded/killed -> Sending Offline event');
      _notifyOfflineStatus();
    }
  }

  void _notifyOnlineStatus() {
    final currentUser = ref.read(userProvider);
    final currentUserId = currentUser?.id ?? ref.read(currentUserProvider);
    if (currentUserId != null && currentUserId.isNotEmpty) {
      debugPrint(
          '🟢 [USER LIST PAGE] Sending online status for: $currentUserId');
      ref.read(chatRepositoryProvider).setUserOnline(currentUserId);
    }
  }

  void _notifyOfflineStatus() {
    final currentUser = ref.read(userProvider);
    final currentUserId = currentUser?.id ?? ref.read(currentUserProvider);
    if (currentUserId != null && currentUserId.isNotEmpty) {
      debugPrint(
          '🔴 [USER LIST PAGE] Sending offline status for: $currentUserId');
      ref.read(chatRepositoryProvider).setUserOffline(currentUserId);
    }
  }

  void _showSelectContactBottomSheet(
      BuildContext context, String? currentUserId) {
    ref.invalidate(allUsersProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SelectContactBottomSheet(
        currentUserId: currentUserId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(allChatUsersProvider);
    final conversationsAsync = ref.watch(conversationsProvider);
    final currentUser = ref.watch(userProvider);
    final currentUserId = currentUser?.id;

    // Auto-refresh chat user list if a new message arrives from a user not yet in home list
    ref.listen(conversationsProvider, (previous, next) {
      next.whenData((convList) {
        final currentUsers = ref.read(allChatUsersProvider).value ?? [];
        final existingUserIds = currentUsers.map((u) => u.id).toSet();
        for (var conv in convList) {
          if (conv.participantId.isNotEmpty &&
              !existingUserIds.contains(conv.participantId)) {
            ref.invalidate(allChatUsersProvider);
            break;
          }
        }
      });
    });

    // Map of conversation data keyed by participant ID
    final conversationsMap = <String, Conversation>{};
    conversationsAsync.whenData((convList) {
      for (var conv in convList) {
        conversationsMap[conv.participantId] = conv;
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        tooltip: 'New Chat',
        child: const Icon(Icons.chat_rounded),
        onPressed: () => _showSelectContactBottomSheet(context, currentUserId),
      ),
      appBar: AppBar(
        backgroundColor: AppColors.appBarColor,
        elevation: 0,
        scrolledUnderElevation: 2,
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hi, ${currentUser?.name ?? 'Friend'} 👋',
                    style: const TextStyle(
                      color: AppColors.appBarTitleColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded, color: Colors.white),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          ref.invalidate(allChatUsersProvider);
          ref.invalidate(conversationsProvider);
        },
        child: usersAsync.when(
          data: (users) {
            final otherUsers =
                users.where((u) => u.id != currentUserId).toList();

            if (otherUsers.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 80.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline_rounded,
                              size: 64, color: AppColors.textSubtle),
                          const SizedBox(height: 12),
                          const Text(
                            'No other contacts found',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: otherUsers.length,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
              itemBuilder: (context, index) {
                final initialUser = otherUsers[index];
                return Consumer(
                  builder: (context, ref, child) {
                    final presenceAsync =
                        ref.watch(userPresenceProvider(initialUser.id));
                    final user = presenceAsync.value ?? initialUser;

                    // Match conversation for unread count & last message preview
                    final conversationId = IChatRepository.getConversationId(
                        currentUserId ?? '', user.id);
                    final conversation = conversationsMap[user.id] ??
                        conversationsMap[conversationId];
                    final unreadCount = conversation?.unreadCount ?? 0;
                    final lastMsgText = conversation?.lastMessageText;
                    final lastMsgTimeStr =
                        DateFormatter.formatTime(conversation?.lastMessageAt);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Material(
                        color: AppColors.cardColor,
                        borderRadius: BorderRadius.circular(14),
                        elevation: 0,
                        child: InkWell(
                          onTap: () async {
                            final repo = ref.read(chatRepositoryProvider);
                            final targetConvId =
                                await repo.getOrCreateConversation(
                              currentUserId ?? '',
                              user.id,
                            );

                            if (context.mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatDetailPage(
                                    conversationId: targetConvId,
                                    participant: user,
                                  ),
                                ),
                              );
                            }
                          },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14.0, vertical: 12.0),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                // Avatar with Online Indicator
                                Stack(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: user.isOnline
                                              ? AppColors.onlineGreen
                                              : Colors.transparent,
                                          width: 2,
                                        ),
                                      ),
                                      child: CircleAvatar(
                                        radius: 26,
                                        backgroundColor: AppColors.primary,
                                        backgroundImage:
                                            user.avatarUrl != null &&
                                                    user.avatarUrl!.isNotEmpty
                                                ? NetworkImage(user.avatarUrl!)
                                                : null,
                                        child: (user.avatarUrl == null ||
                                                user.avatarUrl!.isEmpty)
                                            ? Text(
                                                user.name.isNotEmpty
                                                    ? user.name[0].toUpperCase()
                                                    : '?',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              )
                                            : null,
                                      ),
                                    ),
                                    Positioned(
                                      right: 2,
                                      bottom: 2,
                                      child: Container(
                                        width: 13,
                                        height: 13,
                                        decoration: BoxDecoration(
                                          color: user.isOnline
                                              ? AppColors.onlineGreen
                                              : AppColors.offlineGrey,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: Colors.white, width: 2),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 14),

                                // User Name & Subtitle Preview / Typing Status
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user.name,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: unreadCount > 0
                                              ? FontWeight.w900
                                              : FontWeight.bold,
                                          color: AppColors.textPrimary,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Builder(
                                        builder: (context) {
                                          final isTypingAsync = ref.watch(
                                              userTypingStatusProvider(
                                                  user.id));
                                          final isTyping =
                                              isTypingAsync.value ?? false;

                                          if (isTyping) {
                                            return const Row(
                                              children: [
                                                Icon(Icons.edit_note_rounded,
                                                    size: 16,
                                                    color: AppColors.accent),
                                                SizedBox(width: 4),
                                                Text(
                                                  'typing...',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: AppColors.accent,
                                                    fontWeight: FontWeight.w600,
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                                ),
                                              ],
                                            );
                                          }

                                          if (lastMsgText != null &&
                                              lastMsgText.isNotEmpty) {
                                            return Text(
                                              lastMsgText,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w400,
                                                color: AppColors.textSecondary,
                                              ),
                                            );
                                          }

                                          return Text(
                                            user.isOnline
                                                ? 'Online now'
                                                : 'Offline',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: user.isOnline
                                                  ? AppColors.onlineGreen
                                                  : AppColors.textSubtle,
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Right Trailing Side: Time & WhatsApp Unread Badge
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (lastMsgTimeStr.isNotEmpty)
                                      Text(
                                        lastMsgTimeStr,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: unreadCount > 0
                                              ? FontWeight.bold
                                              : FontWeight.w400,
                                          color: unreadCount > 0
                                              ? AppColors.accent
                                              : AppColors.textSubtle,
                                        ),
                                      ),
                                    const SizedBox(height: 4),
                                    if (unreadCount > 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 7, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppColors.accent,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        constraints: const BoxConstraints(
                                          minWidth: 20,
                                          minHeight: 20,
                                        ),
                                        child: Center(
                                          child: Text(
                                            unreadCount > 99
                                                ? '99+'
                                                : '$unreadCount',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets.all(7),
                                        decoration: const BoxDecoration(
                                          color: AppColors.inputBackground,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.chat_bubble_rounded,
                                          color: AppColors.primary,
                                          size: 16,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
          error: (err, stack) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 80.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 16),
                      const Text(
                        'Network Connection Error',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0),
                        child: Text(
                          'Unable to connect to server. Please check your network or server status and try again.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
