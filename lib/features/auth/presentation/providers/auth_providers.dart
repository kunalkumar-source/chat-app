import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/network/api_service.dart';
import '../../../../core/network/network_exceptions.dart';
import '../../../../core/notification_service.dart';
import '../../../chat/data/models/chat_user_model.dart';
import '../../../chat/presentation/providers/chat_providers.dart';

// --- Auth State ---
enum AuthStatus {
  initial,
  authenticating,
  authenticated,
  unauthenticated,
  error
}

class AuthState {
  final AuthStatus status;
  final String? token;
  final String? error;

  const AuthState({
    this.status = AuthStatus.initial,
    this.token,
    this.error,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? token,
    String? error,
  }) {
    return AuthState(
      status: status ?? this.status,
      token: token ?? this.token,
      error: error ?? this.error,
    );
  }
}

// --- Auth Notifier ---
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return AuthNotifier(apiService, const FlutterSecureStorage(), ref);
});

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiService _apiService;
  final FlutterSecureStorage _storage;
  final Ref _ref;

  AuthNotifier(this._apiService, this._storage, this._ref)
      : super(const AuthState()) {
    checkAuth();
  }

  Future<void> checkAuth() async {
    final token = await _storage.read(key: 'auth_token');
    if (token != null) {
      state = state.copyWith(status: AuthStatus.authenticated, token: token);

      // Load user profile independently from local storage
      await _ref.read(userProvider.notifier).loadUserFromStorage();

      // Connect Socket & Register Online Status
      final user = _ref.read(userProvider);
      if (user != null) {
        _ref.read(chatRepositoryProvider).setUserOnline(user.id);
        _ref.read(socketClientProvider).connect(token);
      }
    } else {
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(status: AuthStatus.authenticating, error: null);
    try {
      final fcmToken = await NotificationService().getToken();
      final authResponse = await _apiService.login({
        'username': email,
        'password': password,
        if (fcmToken != null) 'fcmToken': fcmToken,
      });

      final token = authResponse.token;
      final user = authResponse.user;

      if (token != null) {
        // Save session token
        await _storage.write(key: 'auth_token', value: token);

        // Update User profile via dedicated notifier
        if (user != null) {
          await _ref.read(userProvider.notifier).updateUser(user);
        }

        state = state.copyWith(status: AuthStatus.authenticated, token: token);
        if (user != null) {
          _ref.read(chatRepositoryProvider).setUserOnline(user.id);
          _ref.read(socketClientProvider).connect(token);
        }
      } else {
        debugPrint('Auth Error: Login successful but token is missing');
        state = state.copyWith(
          status: AuthStatus.error,
          error: 'Authentication failed: Token missing',
        );
      }
    } catch (e, stackTrace) {
      debugPrint("::::::::::: Auth Exception :::::::::::");
      debugPrint(e.toString());
      debugPrint(stackTrace.toString());

      String errorMessage = 'An unexpected error occurred';
      if (e is NetworkExceptions) {
        errorMessage = e.message;
      }

      state = state.copyWith(
        status: AuthStatus.error,
        error: errorMessage,
      );
    }
  }

  Future<void> logout() async {
    try {
      await _apiService.logout();
    } catch (_) {}
    _ref.read(socketClientProvider).disconnect();
    await _storage.delete(key: 'auth_token');
    await _ref.read(userProvider.notifier).clearUser();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

// --- User Profile Notifier (Independent & Scalable) ---
/// This notifier manages the user profile data separately from the auth status.
/// This allows updating user info at runtime without affecting the authentication session.
final userProvider = StateNotifierProvider<UserNotifier, ChatUserModel?>((ref) {
  return UserNotifier(const FlutterSecureStorage());
});

class UserNotifier extends StateNotifier<ChatUserModel?> {
  final FlutterSecureStorage _storage;
  static const _userKey = 'user_profile_data';

  UserNotifier(this._storage) : super(null);

  Future<void> loadUserFromStorage() async {
    try {
      final userData = await _storage.read(key: _userKey);
      if (userData != null) {
        state = ChatUserModel.fromJson(jsonDecode(userData));
      }
    } catch (e) {
      state = null;
    }
  }

  Future<void> updateUser(ChatUserModel user) async {
    state = user;
    await _storage.write(key: _userKey, value: jsonEncode(user.toJson()));
  }

  /// Update specific fields locally (e.g., status, avatar) without a full refresh
  void updateProfileFields({String? name, String? avatarUrl, bool? isOnline}) {
    if (state != null) {
      final updatedUser = ChatUserModel(
        id: state!.id,
        name: name ?? state!.name,
        avatarUrl: avatarUrl ?? state!.avatarUrl,
        isOnline: isOnline ?? state!.isOnline,
        lastSeen: state!.lastSeen,
      );
      updateUser(updatedUser);
    }
  }

  Future<void> clearUser() async {
    state = null;
    await _storage.delete(key: _userKey);
  }
}
