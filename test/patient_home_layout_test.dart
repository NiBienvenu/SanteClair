import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sante_clair/core/theme/app_theme.dart';
import 'package:sante_clair/data/models/patient.dart';
import 'package:sante_clair/data/models/referentials.dart';
import 'package:sante_clair/data/providers.dart';
import 'package:sante_clair/features/patient/patient_home_screen.dart';

const options = [
  OptionItem(id: 'cardiologue', label: 'Cardiologie', icon: 'heart'),
  OptionItem(id: 'chirurgie', label: 'Chirurgie', icon: 'hospital'),
  OptionItem(id: 'dentiste', label: 'Dentiste', icon: 'tooth'),
  OptionItem(id: 'dermatologue', label: 'Dermatologie', icon: 'hospital'),
  OptionItem(id: 'gynecologue', label: 'Gynécologie', icon: 'hospital'),
  OptionItem(
    id: 'generaliste',
    label: 'Médecine générale',
    icon: 'stethoscope',
  ),
  OptionItem(id: 'pediatre', label: 'Pédiatrie', icon: 'child'),
  OptionItem(id: 'video', label: 'Vidéo', icon: 'video'),
];

const home = PatientHome(
  firstName: 'Amina',
  subtitle: 'Vos soins et rendez-vous',
  verified: true,
  nextAppointment: null,
  quickConsultations: options,
  recentDoctors: [],
);

Future<GoRouter> renderHome(
  WidgetTester tester, {
  double width = 360,
  double height = 1600,
  double scale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const PatientHomeScreen()),
      GoRoute(
        path: '/patient/search',
        builder: (_, state) => Scaffold(body: Text(state.uri.toString())),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [patientHomeProvider.overrideWith((ref) async => home)],
      child: RepaintBoundary(
        key: const ValueKey('home-preview'),
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

void main() {
  for (final width in [320.0, 360.0, 600.0, 1024.0]) {
    testWidgets(
      'specialties stay on one readable scrolling row at width $width',
      (tester) async {
        await renderHome(tester, width: width);
        expect(tester.takeException(), isNull);
        final firstTile = tester.getRect(
          find.byKey(const ValueKey('quick-consultation-cardiologue')),
        );
        for (final option in options) {
          final text = find.text(option.label);
          expect(text, findsOneWidget);
          final paragraph = tester.renderObject<RenderParagraph>(text);
          final lines = paragraph.getBoxesForSelection(
            TextSelection(baseOffset: 0, extentOffset: option.label.length),
          );
          expect(
            lines.length,
            lessThanOrEqualTo(2),
            reason: '${option.label} should not break into fragments',
          );
          final tile = tester.getRect(
            find.byKey(ValueKey('quick-consultation-${option.id}')),
          );
          final label = tester.getRect(text);
          expect(tile.top, firstTile.top);
          expect(tile.height, firstTile.height);
          expect(tile.contains(label.topLeft), isTrue);
          expect(tile.contains(label.bottomRight), isTrue);
        }
        final scroll = find.byKey(const ValueKey('quick-consultations-scroll'));
        final scrollable = find.descendant(
          of: scroll,
          matching: find.byType(Scrollable),
        );
        final position = tester.state<ScrollableState>(scrollable).position;
        expect(position.maxScrollExtent, greaterThan(0));
        await tester.drag(
          scroll,
          const Offset(-500, 0),
          kind: width >= 600
              ? PointerDeviceKind.mouse
              : PointerDeviceKind.touch,
        );
        await tester.pumpAndSettle();
        expect(position.pixels, greaterThan(0));
        expect(tester.takeException(), isNull);
        expect(find.text('Aucun médecin récent'), findsOneWidget);
      },
    );
  }

  testWidgets('larger text stays inside specialty cards', (tester) async {
    await renderHome(tester, width: 320, scale: 1.8);
    await tester.ensureVisible(find.text('Vidéo'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final paragraph = tester.renderObject<RenderParagraph>(
      find.text('Médecine générale'),
    );
    expect(paragraph.didExceedMaxLines, isFalse);
  });

  testWidgets('specialty and video cards retain their search filters', (
    tester,
  ) async {
    final router = await renderHome(tester);
    await tester.ensureVisible(find.text('Médecine générale'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Médecine générale'));
    await tester.pumpAndSettle();
    expect(find.text('/patient/search?specialty=generaliste'), findsOneWidget);
    router.pop();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Vidéo'));
    await tester.tap(find.text('Vidéo'));
    await tester.pumpAndSettle();
    expect(find.text('/patient/search?video=true'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  if (const bool.fromEnvironment('SAVE_HOME_PREVIEW')) {
    testWidgets('save a rendered mobile preview', (tester) async {
      const fonts = String.fromEnvironment('PREVIEW_FONT_DIRECTORY');
      if (fonts.isNotEmpty) {
        await tester.runAsync(() async {
          final roboto = FontLoader('Roboto');
          for (final file in ['Roboto-Regular.ttf', 'Roboto-Bold.ttf']) {
            roboto.addFont(
              File('$fonts/$file')
                  .readAsBytes()
                  .then((bytes) => ByteData.sublistView(bytes)),
            );
          }
          await roboto.load();
          await (FontLoader('MaterialIcons')
                ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
              .load();
        });
      }
      await renderHome(tester, width: 390, height: 1100);
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const ValueKey('home-preview')),
        );
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('/tmp/santeclair-patient-home.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    });
  }
}
