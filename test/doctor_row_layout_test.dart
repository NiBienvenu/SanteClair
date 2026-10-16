import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sante_clair/core/theme/app_theme.dart';
import 'package:sante_clair/data/models/doctor.dart';
import 'package:sante_clair/features/patient/patient_home_screen.dart';

const doctor = Doctor(
  id: 'new-doctor',
  firstName: 'Claire',
  lastName: 'Fontaine',
  specialty: 'Dermatologie',
  specialtyKey: 'dermatologue',
  fee: 20000,
  currency: 'FBU',
  verified: true,
  teleconsultation: false,
  address: 'Centre Dermatologique, Marseille',
  cabinetName: 'Centre Dermatologique',
  phone: '12345678',
);

void main() {
  for (final width in [320.0, 360.0, 464.0]) {
    testWidgets('doctor and booking action share a compact row at $width', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      var pressed = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.topCenter,
                child: DoctorRow(
                  doctor: doctor,
                  showFee: true,
                  action: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 34),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    onPressed: () => pressed = true,
                    child: const Text('Prendre RDV'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final card = tester.getRect(find.byType(DoctorRow));
      final button = tester.getRect(find.byType(FilledButton));
      final name = tester.getRect(find.text(doctor.displayName));
      expect(card.height, lessThan(120));
      expect(button.center.dy, closeTo(card.center.dy, 1));
      expect(button.left, greaterThan(name.right));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Prendre RDV'));
      expect(pressed, isTrue);
    });
  }
}
