import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sante_clair/core/network/api_client.dart';
import 'package:sante_clair/core/network/api_exception.dart';
import 'package:sante_clair/data/models/app_user.dart';

void main() {
  test(
    'parallel expired requests share a refresh and retry with the new token',
    () async {
      var token = 'expired';
      var refreshes = 0;
      var logouts = 0;
      final api = ApiClient(
        useMock: false,
        tokenProvider: () => token,
        refreshTokenProvider: () => 'refresh-token',
        onTokenRefreshed: (value) async => token = value,
        onUnauthorized: () => logouts++,
      );
      api.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            if (options.path == '/auth/refresh') {
              refreshes++;
              await Future<void>.delayed(const Duration(milliseconds: 10));
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {'access': 'new-token'},
                ),
              );
            } else if (options.headers['Authorization'] == 'Bearer new-token') {
              handler.resolve(
                Response(
                  requestOptions: options,
                  statusCode: 200,
                  data: {'ok': true},
                ),
              );
            } else {
              handler.reject(
                DioException.badResponse(
                  statusCode: 401,
                  requestOptions: options,
                  response: Response(
                    requestOptions: options,
                    statusCode: 401,
                    data: {'message': 'Expired'},
                  ),
                ),
              );
            }
          },
        ),
      );
      final results = await Future.wait([
        api.get('/profile'),
        api.get('/patient/home'),
      ]);
      expect(results.every((value) => (value as Map)['ok'] == true), isTrue);
      expect(refreshes, 1);
      expect(logouts, 0);
      api.dio.close();
    },
  );

  test(
    'an invalid refresh ends the session and preserves the API error',
    () async {
      var logouts = 0;
      final api = ApiClient(
        useMock: false,
        tokenProvider: () => 'expired',
        refreshTokenProvider: () => 'invalid',
        onTokenRefreshed: (_) async {},
        onUnauthorized: () => logouts++,
      );
      api.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.reject(
              DioException.badResponse(
                statusCode: 401,
                requestOptions: options,
                response: Response(
                  requestOptions: options,
                  statusCode: 401,
                  data: {'message': 'Session expirée'},
                ),
              ),
            );
          },
        ),
      );
      await expectLater(
        api.get('/profile'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
      );
      expect(logouts, 1);
      api.dio.close();
    },
  );

  test('refresh tokens survive session storage serialization', () {
    final session = AuthSession.fromJson({
      'token': 'access',
      'refresh': 'refresh',
      'user': {
        'id': 'uuid',
        'role': 'patient',
        'firstName': 'Amina',
        'lastName': 'Koné',
        'email': 'patient@example.com',
        'phone': '12345678',
      },
    });
    expect(AuthSession.fromJson(session.toJson()).refreshToken, 'refresh');
  });
}
