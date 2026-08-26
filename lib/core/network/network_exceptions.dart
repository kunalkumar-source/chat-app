import 'dart:io';
import 'package:dio/dio.dart';

class NetworkExceptions {
  final String message;
  final int? statusCode;

  NetworkExceptions({required this.message, this.statusCode});

  factory NetworkExceptions.handleResponse(Response? response) {
    int statusCode = response?.statusCode ?? 0;
    switch (statusCode) {
      case 400:
        return NetworkExceptions(message: "Bad request", statusCode: statusCode);
      case 401:
        return NetworkExceptions(message: "Unauthorized", statusCode: statusCode);
      case 403:
        return NetworkExceptions(message: "Forbidden", statusCode: statusCode);
      case 404:
        return NetworkExceptions(message: "Not found", statusCode: statusCode);
      case 409:
        return NetworkExceptions(message: "Conflict", statusCode: statusCode);
      case 408:
        return NetworkExceptions(message: "Request timeout", statusCode: statusCode);
      case 500:
        return NetworkExceptions(message: "Internal server error", statusCode: statusCode);
      case 503:
        return NetworkExceptions(message: "Service unavailable", statusCode: statusCode);
      default:
        return NetworkExceptions(
          message: "Received invalid status code: $statusCode",
          statusCode: statusCode,
        );
    }
  }

  factory NetworkExceptions.getDioException(dynamic error) {
    if (error is Exception) {
      try {
        if (error is DioException) {
          switch (error.type) {
            case DioExceptionType.cancel:
              return NetworkExceptions(message: "Request cancelled");
            case DioExceptionType.connectionTimeout:
              return NetworkExceptions(message: "Connection timeout");
            case DioExceptionType.receiveTimeout:
              return NetworkExceptions(message: "Receive timeout");
            case DioExceptionType.sendTimeout:
              return NetworkExceptions(message: "Send timeout");
            case DioExceptionType.badResponse:
              final data = error.response?.data;
              String? errorMessage;
              if (data is Map && data.containsKey('message')) {
                errorMessage = data['message'];
              }
              return NetworkExceptions(
                message: errorMessage ?? NetworkExceptions.handleResponse(error.response).message,
                statusCode: error.response?.statusCode,
              );
            case DioExceptionType.connectionError:
              return NetworkExceptions(message: "No internet connection");
            default:
              return NetworkExceptions(message: "Unexpected error occurred");
          }
        } else if (error is SocketException) {
          return NetworkExceptions(message: "No internet connection");
        } else {
          return NetworkExceptions(message: "Unexpected error occurred");
        }
      } catch (_) {
        return NetworkExceptions(message: "Unexpected error occurred");
      }
    } else {
      if (error.toString().contains("is not a subtype of")) {
        return NetworkExceptions(message: "Unable to process the data");
      } else {
        return NetworkExceptions(message: "Unexpected error occurred");
      }
    }
  }

  @override
  String toString() => message;
}
