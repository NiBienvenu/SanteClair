import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sante_clair/core/theme/app_theme.dart';
import 'package:sante_clair/features/video/incoming_calls_banner.dart';
import 'package:sante_clair/features/video/video_repository.dart';

void main() {
  testWidgets(
    'Incoming patient call keeps the doctor screen laid out with the app theme',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final calls = StreamController<List<IncomingCall>>();
      addTearDown(() {
        unawaited(calls.close());
      });
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/doctor',
            builder: (_, _) => Scaffold(
              body: Column(
                children: [
                  const IncomingCallsBanner(),
                  const Expanded(child: Center(child: Text('Espace médecin'))),
                ],
              ),
            ),
          ),
          GoRoute(
            path: '/doctor/video/:appointmentId',
            builder: (_, state) => Scaffold(
              body: Text('Appel ${state.pathParameters['appointmentId']}'),
            ),
          ),
        ],
        initialLocation: '/doctor',
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            incomingCallsProvider.overrideWith((ref) => calls.stream),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Espace médecin'), findsOneWidget);
      calls.add([
        IncomingCall.fromJson({
          'appointmentId': 'appointment-1',
          'patientName': 'Patient Test',
          'urgent': true,
          'amountDue': 10000,
        }),
      ]);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Espace médecin'), findsOneWidget);
      expect(find.text('Appel urgent · Patient Test'), findsOneWidget);
      await tester.tap(find.text('Rejoindre'));
      await tester.pumpAndSettle();
      expect(find.text('Appel appointment-1'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final width in [320.0, 360.0]) {
    testWidgets(
      'Multiple calls preserve the doctor screen at $width with large text',
      (tester) async {
        tester.view.physicalSize = Size(width, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              incomingCallsProvider.overrideWith(
                (ref) => Stream.value([
                  for (var index = 0; index < 3; index++)
                    IncomingCall.fromJson({
                      'appointmentId': 'appointment-$index',
                      'patientName': 'Patient avec un nom et un prénom longs',
                      'urgent': index == 0,
                      'amountDue': index == 0 ? 10000 : 0,
                    }),
                ]),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(2)),
                child: child!,
              ),
              home: const Scaffold(
                body: Column(
                  children: [
                    IncomingCallsBanner(),
                    Expanded(child: Center(child: Text('Espace médecin'))),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Espace médecin'), findsOneWidget);
        expect(
          tester.getRect(find.text('Espace médecin')).bottom,
          lessThanOrEqualTo(700),
        );
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
