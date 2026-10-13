import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import 'api_exception.dart';
import 'mock/mock_interceptor.dart';

class ApiClient {
  ApiClient({
    required String? Function() tokenProvider,
    this.onUnauthorized,
  }) : dio = Dio(
         BaseOptions(
           baseUrl: AppConfig.baseUrl,
           connectTimeout: const Duration(seconds: 15),
           receiveTimeout: const Duration(seconds: 20),
           headers: {'Accept': 'application/json'},
         ),
       ) {
    dio.interceptors.add(_AuthInterceptor(tokenProvider));
    if (kDebugMode) {
      dio.interceptors.add(
        LogInterceptor(
          request: false,
          requestHeader: false,
          requestBody: true,
          responseHeader: false,
          responseBody: false,
          logPrint: (o) => debugPrint(o.toString()),
        ),
      );
    }
    if (AppConfig.useMock) dio.interceptors.add(MockInterceptor());
  }

  final Dio dio;
  final void Function()? onUnauthorized;

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(path, () => dio.get(path, queryParameters: query));

  Future<dynamic> post(String path, {Object? data}) =>
      _send(path, () => dio.post(path, data: data));

  Future<dynamic> put(String path, {Object? data}) =>
      _send(path, () => dio.put(path, data: data));

  Future<dynamic> patch(String path, {Object? data}) =>
      _send(path, () => dio.patch(path, data: data));

  Future<dynamic> delete(String path) => _send(path, () => dio.delete(path));

  Future<dynamic> _send(
    String path,
    Future<Response<dynamic>> Function() request,
  ) async {
    try {
      final response = await request();
      return response.data;
    } on DioException catch (e) {
      final error = ApiException.fromDio(e);
      if (error.statusCode == 401 && !path.startsWith('/auth/')) {
        onUnauthorized?.call();
      }
      throw error;
    }
  }
}

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._tokenProvider);

  final String? Function() _tokenProvider;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _tokenProvider();
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }
}
