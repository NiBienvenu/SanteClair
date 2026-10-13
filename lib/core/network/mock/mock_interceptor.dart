import 'package:dio/dio.dart';

import '../../config/app_config.dart';
import 'mock_backend.dart';

/// Intercepte les requêtes Dio et y répond avec les données de
/// `assets/mock/*.json`, comme le ferait le vrai backend.
class MockInterceptor extends Interceptor {
  MockInterceptor({MockBackend? backend}) : _backend = backend ?? MockBackend();

  final MockBackend _backend;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    await Future<void>.delayed(AppConfig.mockLatency);
    try {
      final result = await _backend.handle(
        method: options.method,
        path: Uri.parse(options.path).path,
        query: options.queryParameters,
        body: options.data,
        headers: options.headers,
      );
      handler.resolve(
        Response(
          requestOptions: options,
          statusCode: result.statusCode,
          data: result.data,
        ),
      );
    } on MockHttpError catch (e) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: options,
            statusCode: e.statusCode,
            data: {'message': e.message, 'errors': e.errors},
          ),
        ),
      );
    }
  }
}
