import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sante_clair/core/network/api_client.dart';
import 'package:sante_clair/features/video/teleconsultation_sheet.dart';
import 'package:sante_clair/features/video/video_repository.dart';

class FakeVideoRepository extends VideoRepository {
  FakeVideoRepository({
    this.ready = false,
    this.urgent = true,
    this.confirmation = false,
  }) : super(ApiClient(tokenProvider: () => null, useMock: false));
  bool ready, urgent, confirmation;
  int reads = 0;

  @override
  Future<CallAccess> access(String id) async {
    reads++;
    return CallAccess.fromJson({
      'appointmentId': id,
      'canJoin': ready,
      'canJoinUrgent': urgent,
      'requiresConfirmation': confirmation,
      'scheduledAt': '2030-01-07T09:00:00+02:00',
      'serverNow': '2030-01-07T08:00:00+02:00',
      'tokenAvailable': false,
      'appSignAllowed': true,
    });
  }
}

Future<GoRouter> openSheet(
  WidgetTester tester,
  FakeVideoRepository repo, {
  bool joinWhenAvailable = false,
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(
          body: TextButton(
            onPressed: () => showTeleconsultation(
              context,
              'appointment-1',
              phone: '68623374',
              joinWhenAvailable: joinWhenAvailable,
            ),
            child: const Text('Ouvrir'),
          ),
        ),
      ),
      GoRoute(
        path: '/patient/video/:id',
        builder: (_, state) => Scaffold(
          body: Text(
            'Appel ${state.pathParameters['id']} urgent=${state.uri.queryParameters['urgent']}',
          ),
        ),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [videoRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.tap(find.text('Ouvrir'));
  await tester.pumpAndSettle();
  return router;
}

void main() {
  test('Urgent visibility uses server time and excludes expired or closed appointments', () {
    Map<String, dynamic> response(String status, String scheduledAt) => {
      'appointmentId': 'appointment-1',
      'scheduledAt': scheduledAt,
      'serverNow': '2030-01-07T08:00:00+02:00',
      'canJoin': false,
      'canJoinUrgent': false,
      'requiresConfirmation': status == 'payment_submitted',
    };
    expect(
      CallAccess.fromJson(
        response('payment_submitted', '2030-01-07T09:00:00+02:00'),
      ).showUrgentJoin,
      isTrue,
    );
    expect(
      CallAccess.fromJson(
        response('payment_submitted', '2030-01-07T07:00:00+02:00'),
      ).showUrgentJoin,
      isFalse,
    );
    expect(
      CallAccess.fromJson(response('cancelled', '2030-01-07T09:00:00+02:00'))
          .showUrgentJoin,
      isFalse,
    );
  });

  testWidgets(
    'Main join opens the call directly when the server authorizes it',
    (tester) async {
      final router = await openSheet(
        tester,
        FakeVideoRepository(ready: true, urgent: false),
        joinWhenAvailable: true,
      );
      expect(find.text('Appel appointment-1 urgent=null'), findsOneWidget);
      expect(find.text('Contacter le cabinet'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      router.dispose();
    },
  );

  testWidgets(
    'Urgent stays below cabinet and requires accepting the payable fee',
    (tester) async {
      final router = await openSheet(tester, FakeVideoRepository());
      expect(find.text('Rejoindre urgent (10 000 FBU)'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Rejoindre urgent (10 000 FBU)')).dy,
        greaterThan(tester.getTopLeft(find.text('Contacter le cabinet')).dy),
      );
      await tester.tap(find.text('Rejoindre urgent (10 000 FBU)'));
      await tester.pumpAndSettle();
      expect(find.textContaining('à régler au cabinet'), findsOneWidget);
      await tester.tap(find.text('Accepter et rejoindre'));
      await tester.pumpAndSettle();
      expect(find.text('Appel appointment-1 urgent=true'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      router.dispose();
    },
  );

  testWidgets(
    'At appointment time the standard join opens without surcharge dialog',
    (tester) async {
      final router = await openSheet(
        tester,
        FakeVideoRepository(ready: true, urgent: false),
      );
      expect(find.text('Rejoindre urgent (10 000 FBU)'), findsNothing);
      await tester.tap(find.text('Rejoindre'));
      await tester.pumpAndSettle();
      expect(find.text('Appel appointment-1 urgent=null'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      router.dispose();
    },
  );

  testWidgets(
    'Pending appointment cannot join and time refresh enables a due appointment',
    (tester) async {
      final repo = FakeVideoRepository(urgent: false, confirmation: true);
      final router = await openSheet(tester, repo);
      expect(find.text('Rejoindre'), findsNothing);
      expect(find.textContaining('doit être confirmé'), findsOneWidget);
      final urgentButton = find.widgetWithText(
        FilledButton,
        'Rejoindre urgent (10 000 FBU)',
      );
      expect(urgentButton, findsOneWidget);
      expect(tester.widget<FilledButton>(urgentButton).onPressed, isNull);
      expect(
        find.textContaining('Disponible dès que le médecin'),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(urgentButton).dy,
        greaterThan(tester.getTopLeft(find.text('Contacter le cabinet')).dy),
      );
      repo.ready = true;
      repo.confirmation = false;
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(find.text('Rejoindre'), findsOneWidget);
      expect(find.text('Rejoindre urgent (10 000 FBU)'), findsNothing);
      expect(repo.reads, greaterThanOrEqualTo(2));
      await tester.pumpWidget(const SizedBox());
      router.dispose();
    },
  );
}
