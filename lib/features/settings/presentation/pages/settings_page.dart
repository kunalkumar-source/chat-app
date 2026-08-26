import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:testingfeature/core/theme/app_colors.dart';
import 'package:testingfeature/features/auth/presentation/providers/auth_providers.dart';
import 'package:testingfeature/features/chat/presentation/providers/chat_providers.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _isProcessing = false;

  void _showExportBackupConfirmationDialog(String userId) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.cloud_upload_rounded, color: AppColors.primary),
            SizedBox(width: 10),
            Text(
              'Back up chats?',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: const Text(
          'Do you want to create a local backup of your messages and conversations on this device?',
          style: TextStyle(
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
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.pop(dialogContext);
              _handleExportBackup(userId);
            },
            child: const Text(
              'Back Up',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleExportBackup(String userId) async {
    setState(() => _isProcessing = true);
    try {
      final repo = ref.read(chatRepositoryProvider);
      final path = await repo.exportChatBackup(userId);

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Row(
              children: [
                Icon(Icons.cloud_upload_rounded, color: AppColors.primary),
                SizedBox(width: 10),
                Text('Backup Complete',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your chat backup has been created successfully!',
                  style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.inputBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    path,
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup Failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showImportOptionsDialog(String userId) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.system_update_alt_rounded, color: AppColors.primary),
            SizedBox(width: 10),
            Text('Restore Chat Backup',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select how you would like to restore your chat backup:',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),

            // Option 1: Auto-Detect
            Material(
              color: AppColors.inputBackground,
              borderRadius: BorderRadius.circular(12),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: const CircleAvatar(
                  backgroundColor: AppColors.primary,
                  child: Icon(Icons.saved_search_rounded, color: Colors.white),
                ),
                title: const Text(
                  'Auto-detect Backup',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.textPrimary),
                ),
                subtitle: const Text(
                  'Search saved location for your account',
                  style:
                      TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                onTap: () {
                  Navigator.pop(dialogContext);
                  _handleAutoImportBackup(userId);
                },
              ),
            ),
            const SizedBox(height: 10),

            // Option 2: Select Manually
            Material(
              color: AppColors.inputBackground,
              borderRadius: BorderRadius.circular(12),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: const CircleAvatar(
                  backgroundColor: AppColors.secondary,
                  child: Icon(Icons.folder_open_rounded, color: Colors.white),
                ),
                title: const Text(
                  'Select File Manually',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.textPrimary),
                ),
                subtitle: const Text(
                  'Browse and pick backup .json file from storage',
                  style:
                      TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                onTap: () {
                  Navigator.pop(dialogContext);
                  _handleManualImportBackup(userId);
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAutoImportBackup(String userId) async {
    setState(() => _isProcessing = true);
    try {
      final repo = ref.read(chatRepositoryProvider);
      final autoPath = await repo.getAutoBackupFilePath(userId);

      if (autoPath == null) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: AppColors.offlineGrey),
                  SizedBox(width: 10),
                  Text('No Backup Found',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: Text(
                'No automatic backup file was found in default storage for your account (User ID: $userId).\n\nPlease use "Select File Manually" if you saved the file elsewhere.',
                style:
                    const TextStyle(fontSize: 13, color: AppColors.textPrimary),
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _handleManualImportBackup(userId);
                  },
                  child: const Text('Browse File'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel',
                      style: TextStyle(color: AppColors.textSecondary)),
                ),
              ],
            ),
          );
        }
        return;
      }

      final count = await repo.importChatBackup(autoPath, userId);

      ref.invalidate(conversationsProvider);
      ref.invalidate(allUsersProvider);

      if (mounted) {
        _showSuccessImportDialog('Auto-Detected Backup Restored!',
            'Successfully restored $count messages from your automatic saved backup!');
      }
    } catch (e) {
      if (mounted) _showErrorImportDialog(e);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleManualImportBackup(String userId) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.single.path == null) {
        return;
      }

      final filePath = result.files.single.path!;
      setState(() => _isProcessing = true);

      final repo = ref.read(chatRepositoryProvider);
      final count = await repo.importChatBackup(filePath, userId);

      ref.invalidate(conversationsProvider);
      ref.invalidate(allUsersProvider);

      if (mounted) {
        _showSuccessImportDialog('Manual Import Successful!',
            'Successfully imported $count messages from the selected backup file into your account!');
      }
    } catch (e) {
      if (mounted) _showErrorImportDialog(e);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showSuccessImportDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: AppColors.onlineGreen),
            const SizedBox(width: 10),
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showErrorImportDialog(dynamic error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.error_outline_rounded, color: Colors.redAccent),
            SizedBox(width: 10),
            Text('Import Failed',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.redAccent)),
          ],
        ),
        content: Text(
          error.toString().replaceAll('Exception: ', ''),
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  void _showClearAllChatsDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
            SizedBox(width: 10),
            Text(
              'Clear All Chats?',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.redAccent,
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to delete all local chat messages and history from this device?\n\nThis action cannot be undone unless you exported a backup file.',
          style: TextStyle(
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
              setState(() => _isProcessing = true);
              try {
                await ref.read(chatRepositoryProvider).clearAllChats();
                ref.invalidate(conversationsProvider);
                ref.invalidate(allUsersProvider);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All local chats cleared successfully.'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to clear chats: $e'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              } finally {
                if (mounted) setState(() => _isProcessing = false);
              }
            },
            child: const Text(
              'Clear All',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.redAccent),
            SizedBox(width: 10),
            Text(
              'Log out?',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to log out of your account?',
          style: TextStyle(
            color: AppColors.textSecondary,
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
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.pop(context);
              ref.read(authProvider.notifier).logout();
            },
            child: const Text(
              'Log Out',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProvider);
    final userId = user?.id ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.appBarColor,
        foregroundColor: AppColors.appBarTitleColor,
        elevation: 0,
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: Stack(
        children: [
          ListView(
            children: [
              const SizedBox(height: 8),

              // WhatsApp Style User Profile Header Card
              Material(
                color: AppColors.cardColor,
                child: InkWell(
                  onTap: () {},
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 14.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.15),
                          child: Text(
                            user?.name.isNotEmpty == true
                                ? user!.name[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.name ?? 'User',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 3),
                              const Text(
                                'Hey there! I am using WhatsApp.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.qr_code_rounded,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              // _buildSectionHeader('ACCOUNT & SECURITY'),
              // Material(
              //   color: AppColors.cardColor,
              //   child: Column(
              //     children: [
              //       _buildSettingsTile(
              //         icon: Icons.key_rounded,
              //         title: 'Account',
              //         subtitle: 'Security notifications, change number',
              //         onTap: () {},
              //       ),
              //       const Divider(
              //           height: 1, indent: 56, color: AppColors.border),
              //       _buildSettingsTile(
              //         icon: Icons.lock_rounded,
              //         title: 'Privacy',
              //         subtitle: 'Block contacts, disappearing messages',
              //         onTap: () {},
              //       ),
              //     ],
              //   ),
              // ),

              const SizedBox(height: 16),
              _buildSectionHeader('CHATS & BACKUP'),
              Material(
                color: AppColors.cardColor,
                child: Column(
                  children: [
                    _buildSettingsTile(
                      icon: Icons.cloud_upload_rounded,
                      title: 'Export Chat Backup',
                      subtitle:
                          'Save messages & conversations to local backup file',
                      onTap: userId.isEmpty
                          ? () {}
                          : () => _showExportBackupConfirmationDialog(userId),
                    ),
                    const Divider(
                        height: 1, indent: 56, color: AppColors.border),
                    _buildSettingsTile(
                      icon: Icons.system_update_alt_rounded,
                      title: 'Import / Restore Chat Backup',
                      subtitle: 'Restore chats (Auto-detect or Select file)',
                      onTap: userId.isEmpty
                          ? () {}
                          : () => _showImportOptionsDialog(userId),
                    ),
                    const Divider(
                        height: 1, indent: 56, color: AppColors.border),
                    _buildSettingsTile(
                      icon: Icons.delete_sweep_rounded,
                      title: 'Clear All Chats',
                      subtitle:
                          'Delete all messages and chat history from device',
                      titleColor: Colors.redAccent,
                      iconColor: Colors.redAccent,
                      onTap: () => _showClearAllChatsDialog(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              _buildSectionHeader('APP SESSION'),
              Material(
                color: AppColors.cardColor,
                child: ListTile(
                  leading:
                      const Icon(Icons.logout_rounded, color: Colors.redAccent),
                  title: const Text(
                    'Log Out',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: const Text(
                    'Sign out of your account on this device',
                    style: TextStyle(fontSize: 12, color: AppColors.textSubtle),
                  ),
                  onTap: () => _showLogoutDialog(context, ref),
                ),
              ),
              const SizedBox(height: 36),
            ],
          ),
          if (_isProcessing)
            Container(
              color: Colors.black38,
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
    Color? titleColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? AppColors.primary),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: titleColor ?? AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
        ),
      ),
      onTap: onTap,
    );
  }
}
