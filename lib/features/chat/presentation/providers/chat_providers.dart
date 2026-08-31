import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:testingfeature/core/config/app_config.dart';
import 'package:testingfeature/core/database_helper.dart';
import 'package:testingfeature/core/network/api_client.dart';
import 'package:testingfeature/core/network/api_service.dart';
import 'package:testingfeature/core/network/socket_client.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/repositories/chat_repository_impl.dart';
import '../../domain/entities/chat_user.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/entities/message.dart';
import '../../domain/repositories/chat_repository.dart';

// --- Network & Database Providers ---

/// Global API Client with common configuration
final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = const FlutterSecureStorage();

  return ApiClient(
    baseUrl: AppConfig.baseUrl,
    interceptors: [
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await storage.read(key: 'auth_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
      ),
    ],
  );
});

/// Managed Socket Client with auto-reconnect logic
final socketClientProvider = Provider<SocketClient>((ref) {
  return SocketClient(AppConfig.socketUrl);
});

/// Single API Service for all routes
final apiServiceProvider = Provider<ApiService>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ApiService(apiClient);
});

final databaseHelperProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper();
});


// --- Single Simplified Repository Provider ---

final chatRepositoryProvider = Provider<IChatRepository>((ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  final apiService = ref.watch(apiServiceProvider);
  final socketClient = ref.watch(socketClientProvider);

  final repo = ChatRepositoryImpl(dbHelper, apiService, socketClient);
  ref.onDispose(() => repo.dispose());
  return repo;
});

final chatRepositoryImplProvider = Provider<ChatRepositoryImpl>((ref) {
  return ref.watch(chatRepositoryProvider) as ChatRepositoryImpl;
});

// Stream provider for socket status
final socketStatusProvider = StreamProvider<SocketStatus>((ref) {
  final socket = ref.watch(socketClientProvider);
  return socket.status;
});

// Connectivity provider
final connectivityStatusProvider = StreamProvider<bool>((ref) async* {
  final initial = await Connectivity().checkConnectivity();
  yield initial.any((res) => res != ConnectivityResult.none);

  await for (final results in Connectivity().onConnectivityChanged) {
    yield results.any((res) => res != ConnectivityResult.none);
  }
});

// --- Helper Providers ---

final participantProvider =
    FutureProvider.family<ChatUser?, String>((ref, userId) {
  return ref.watch(chatRepositoryProvider).getParticipant(userId);
});

final userPresenceProvider =
    StreamProvider.family<ChatUser?, String>((ref, userId) {
  final repo = ref.watch(chatRepositoryProvider);
  return repo.watchUserPresence(userId);
});

final userTypingStatusProvider =
    StreamProvider.family<bool, String>((ref, userId) {
  final repo = ref.watch(chatRepositoryProvider);
  return repo.watchTypingStatus(userId);
});

// --- UI State Providers ---

final currentUserProvider = Provider<String?>((ref) {
  final user = ref.watch(userProvider);
  return user?.id;
});

final conversationsProvider = StreamProvider<List<Conversation>>((ref) {
  return ref.watch(chatRepositoryProvider).watchConversations();
});

final allChatUsersProvider = FutureProvider<List<ChatUser>>((ref) {
  return ref.watch(chatRepositoryProvider).getAllChatUsers();
});

final allUsersProvider = FutureProvider<List<ChatUser>>((ref) {
  return ref.watch(chatRepositoryProvider).getAllUsers();
});

final messagesProvider =
    StreamProvider.family<List<Message>, String>((ref, conversationId) {
  return ref.watch(chatRepositoryProvider).watchMessages(conversationId);
});
