import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sante_clair/core/network/api_client.dart';
import 'package:sante_clair/core/network/api_exception.dart';
import 'package:sante_clair/data/models/app_user.dart';
import 'package:sante_clair/data/providers.dart';
import 'package:sante_clair/features/video/video_call_screen.dart';
import 'package:sante_clair/features/video/video_repository.dart';
import 'package:sante_clair/main.dart';
import 'package:sante_clair/router/app_router.dart';

class _DoctorAuth extends AuthController {
  @override
  AuthState build() => const AuthState(
    AuthStatus.authenticated,
    AuthSession(
      token: 'test-session',
      user: AppUser(
        id: 'doctor-test',
        role: UserRole.doctor,
        firstName: 'Doctor',
        lastName: 'Test',
        email: 'doctor@example.test',
        phone: '',
      ),
    ),
  );
}

class _PendingVideoRepository extends VideoRepository {
  _PendingVideoRepository()
    : super(ApiClient(tokenProvider: () => null, useMock: false));
  final result = Completer<CallAccess>();
  @override
  Future<CallAccess> access(String id) => result.future;
}

void main() {
  testWidgets(
    'Real doctor router shows the call while joining and keeps an API error visible',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final video = _PendingVideoRepository();
      addTearDown(video.api.dio.close);
      final incoming = StreamController<List<IncomingCall>>();
      addTearDown(() {
        unawaited(incoming.close());
      });
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          authControllerProvider.overrideWith(_DoctorAuth.new),
          doctorDashboardProvider.overrideWith(
            (ref) async => throw ApiException('Tableau de bord de test'),
          ),
          videoRepositoryProvider.overrideWithValue(video),
          incomingCallsProvider.overrideWith((ref) => incoming.stream),
        ],
      );
      addTearDown(container.dispose);
      final router = container.read(routerProvider);
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const SanteClairApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tableau de bord de test'), findsOneWidget);
      incoming.add([
        IncomingCall.fromJson({
          'appointmentId': 'appointment-1',
          'patientName': 'Patient Test',
          'urgent': true,
          'amountDue': 10000,
        }),
      ]);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Rejoindre'));
      await tester.pumpAndSettle();
      expect(find.byType(VideoCallScreen), findsOneWidget);
      expect(find.byTooltip('Raccrocher'), findsOneWidget);
      expect(find.text('Préparation de l’appel…'), findsWidgets);
      expect(tester.takeException(), isNull);

      video.result.completeError(
        ApiException('Impossible de joindre le cabinet.'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Impossible de joindre le cabinet.'), findsOneWidget);
      expect(find.byTooltip('Raccrocher'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Raccrocher'));
      await tester.pumpAndSettle();
      expect(find.byType(VideoCallScreen), findsNothing);
      expect(find.text('Tableau de bord de test'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
