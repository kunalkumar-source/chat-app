import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:testingfeature/core/theme/app_colors.dart';
import 'package:testingfeature/features/chat/presentation/pages/chat_detail_page.dart';
import 'package:testingfeature/features/chat/presentation/providers/chat_providers.dart';

class SelectContactBottomSheet extends ConsumerStatefulWidget {
  final String? currentUserId;

  const SelectContactBottomSheet({super.key, required this.currentUserId});

  @override
  ConsumerState<SelectContactBottomSheet> createState() =>
      SelectContactBottomSheetState();
}

class SelectContactBottomSheetState
    extends ConsumerState<SelectContactBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allUsersAsync = ref.watch(allUsersProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              // Drag Handle Bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              // Header Title & Close Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    const Text(
                      'Select Contact',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: AppColors.textSecondary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Search Field
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) =>
                      setState(() => _searchQuery = val.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search contacts...',
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: AppColors.textSubtle),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    filled: true,
                    fillColor: AppColors.inputBackground,
                  ),
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
              Expanded(
                child: allUsersAsync.when(
                  data: (users) {
                    final filteredUsers = users.where((u) {
                      final isNotMe = u.id != widget.currentUserId;
                      final matchesQuery = _searchQuery.isEmpty ||
                          u.name.toLowerCase().contains(_searchQuery);
                      return isNotMe && matchesQuery;
                    }).toList();

                    if (filteredUsers.isEmpty) {
                      return const Center(
                        child: Text(
                          'No contacts found',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: scrollController,
                      itemCount: filteredUsers.length,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      itemBuilder: (context, index) {
                        final user = filteredUsers[index];
                        return Material(
                          color: Colors.transparent,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primary,
                              backgroundImage: user.avatarUrl != null &&
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
                                          fontWeight: FontWeight.bold),
                                    )
                                  : null,
                            ),
                            title: Text(
                              user.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            onTap: () async {
                              final repo = ref.read(chatRepositoryProvider);
                              final targetConvId =
                                  await repo.getOrCreateConversation(
                                widget.currentUserId ?? '',
                                user.id,
                              );

                              if (context.mounted) {
                                Navigator.pop(context);
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChatDetailPage(
                                      conversationId: targetConvId,
                                      participant: user,
                                    ),
                                  ),
                                );
                                ref.invalidate(allChatUsersProvider);
                                ref.invalidate(conversationsProvider);
                              }
                            },
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary)),
                  error: (err, stack) => Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Error loading contacts: $err',
                            style: const TextStyle(color: Colors.redAccent)),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () => ref.refresh(allUsersProvider),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
