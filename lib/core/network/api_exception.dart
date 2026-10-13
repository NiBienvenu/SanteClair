import 'package:dio/dio.dart';

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.errors});

  final String message;
  final int? statusCode;
  final Map<String, dynamic>? errors;

  factory ApiException.fromDio(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] is String) {
      return ApiException(
        data['message'] as String,
        statusCode: e.response?.statusCode,
        errors: data['errors'] is Map
            ? Map<String, dynamic>.from(data['errors'] as Map)
            : null,
      );
    }
    final message = switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => 'Délai de connexion dépassé.',
      DioExceptionType.connectionError => 'Impossible de joindre le serveur.',
      DioExceptionType.cancel => 'Requête annulée.',
      _ => 'Une erreur est survenue. Veuillez réessayer.',
    };
    return ApiException(message, statusCode: e.response?.statusCode);
  }

  @override
  String toString() => message;
}
