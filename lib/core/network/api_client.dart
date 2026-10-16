import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import 'api_exception.dart';
import 'api_endpoints.dart';
import 'mock/mock_interceptor.dart';

class ApiClient {
  ApiClient({
    required String? Function() tokenProvider,
    this.onUnauthorized,
    this.refreshTokenProvider,
    this.onTokenRefreshed,
    bool useMock = AppConfig.useMock,
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
          requestBody: false,
          responseHeader: false,
          responseBody: false,
          logPrint: (o) => debugPrint(o.toString()),
        ),
      );
    }
    if (useMock) dio.interceptors.add(MockInterceptor());
  }

  final Dio dio;
  final void Function()? onUnauthorized;
  final String? Function()? refreshTokenProvider;
  final Future<void> Function(String token)? onTokenRefreshed;
  Future<bool>? _refreshing;

  Future<Uint8List> getBytes(String path) async {
    final data = await _send(
      path,
      () => dio.get<List<int>>(
        path,
        options: Options(responseType: ResponseType.bytes),
      ),
    );
    return Uint8List.fromList(List<int>.from(data as List));
  }

  Future<bool> _refreshAccessToken() async {
    final refresh = refreshTokenProvider?.call();
    if (refresh == null || onTokenRefreshed == null) return false;
    try {
      final response = await dio.post<Map<String, dynamic>>(
        ApiEndpoints.refresh,
        data: {'refresh': refresh},
      );
      final token = response.data?['access'];
      if (token is! String) return false;
      await onTokenRefreshed!(token);
      return true;
    } on DioException {
      return false;
    }
  }

  Future<bool> _refreshSession() async {
    final pending = _refreshing;
    if (pending != null) return pending;
    final future = _refreshAccessToken();
    _refreshing = future;
    try {
      return await future;
    } finally {
      _refreshing = null;
    }
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(path, () => dio.get(path, queryParameters: query));

  Future<dynamic> post(String path, {Object? data}) =>
      _send(path, () => dio.post(path, data: _requestData(data)));

  Future<dynamic> put(String path, {Object? data}) =>
      _send(path, () => dio.put(path, data: _requestData(data)));

  Future<dynamic> patch(String path, {Object? data}) =>
      _send(path, () => dio.patch(path, data: _requestData(data)));

  Future<dynamic> delete(String path) => _send(path, () => dio.delete(path));

  Object? _requestData(Object? data) => data is FormData ? data.clone() : data;

  Future<dynamic> _send(
    String path,
    Future<Response<dynamic>> Function() request,
  ) async {
    try {
      final response = await request();
      return response.data;
    } on DioException catch (e) {
      var error = ApiException.fromDio(e);
      if (error.statusCode == 401 && !path.startsWith('/auth/')) {
        if (await _refreshSession()) {
          try {
            return (await request()).data;
          } on DioException catch (retryError) {
            error = ApiException.fromDio(retryError);
          }
        }
        if (error.statusCode == 401) onUnauthorized?.call();
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
