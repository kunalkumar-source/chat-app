import '../../features/auth/data/models/auth_response.dart';
import '../../features/chat/data/models/chat_user_model.dart';
import 'api_client.dart';

class ApiService {
  final ApiClient _apiClient;

  ApiService(this._apiClient);

  // --- Auth Routes ---
  Future<AuthResponse> login(Map<String, dynamic> body) async {
    final response = await _apiClient.post('/api/auth/login', data: body);
    return AuthResponse.fromJson(response.data);
  }

  Future<void> logout() async {
    await _apiClient.post('/api/auth/logout');
  }

  // --- User Routes ---
  Future<ChatUserModel> getMe() async {
    final response = await _apiClient.get('/api/users/me');
    // Based on doc: data: { user: { ... } }
    return ChatUserModel.fromJson(response.data['data']['user']);
  }

  Future<List<ChatUserModel>> getAllUsers() async {
    final response = await _apiClient.get('/api/users');
    final List<dynamic> data = response.data['users'] ?? [];
    return data.map((u) => ChatUserModel.fromJson(u)).toList();
  }
}
