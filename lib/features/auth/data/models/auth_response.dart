import '../../../chat/data/models/chat_user_model.dart';

class AuthResponse {
  final String message;
  final ChatUserModel? user;
  final String? token;

  AuthResponse({
    required this.message,
    this.user,
    this.token,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      message: json['message'] ?? '',
      token: json['token'],
      user: json['user'] != null ? ChatUserModel.fromJson(json['user']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'token': token,
      'user': user?.toJson(),
    };
  }
}
