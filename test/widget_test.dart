import 'package:flutter_test/flutter_test.dart';
import 'package:sante_clair/core/network/api_client.dart';
import 'package:sante_clair/core/network/api_exception.dart';
import 'package:sante_clair/core/utils/formatters.dart';
import 'package:sante_clair/data/models/app_user.dart';
import 'package:sante_clair/data/models/appointment.dart';
import 'package:sante_clair/data/models/doctor_space.dart';
import 'package:sante_clair/data/repositories/auth_repository.dart';
import 'package:sante_clair/data/repositories/doctor_repository.dart';
import 'package:sante_clair/data/repositories/patient_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('formatMoney groups thousands', () {
    expect(formatMoney(15000), '15 000 FBU');
    expect(formatMoney(1250000, 'FCFA'), '1 250 000 FCFA');
  });

  group('mock API through Dio', () {
    late String? token;
    late ApiClient api;

    setUp(() {
      token = null;
      api = ApiClient(tokenProvider: () => token, useMock: true);
    });

    test('login rejects bad credentials and accepts demo account', () async {
      final auth = AuthRepository(api);
      await expectLater(
        auth.login(
          identifier: 'amina.kone@email.com',
          password: 'wrong',
          role: UserRole.patient,
        ),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)),
      );
      final session = await auth.login(
        identifier: 'amina.kone@email.com',
        password: 'Sante@2024',
        role: UserRole.patient,
      );
      expect(session.user.firstName, 'Amina');
    });

    test('booking then payment flows to the doctor dashboard', () async {
      token = (await AuthRepository(api).login(
        identifier: '07 00 12 34 56',
        password: 'Sante@2024',
        role: UserRole.patient,
      )).token;
      final patient = PatientRepository(api);

      final apt = await patient.createAppointment(
        const AppointmentRequest(
          doctorId: 'doc_004',
          reason: 'Première visite',
          date: '2024-10-25',
          time: '10:15',
          mode: 'cabinet',
        ),
      );
      expect(apt.status, AppointmentStatus.pendingPayment);

      await expectLater(
        patient.createAppointment(
          const AppointmentRequest(
            doctorId: 'doc_004',
            reason: 'Urgence',
            date: '2024-10-25',
            time: '10:15',
            mode: 'cabinet',
          ),
        ),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 409)),
      );

      final paid = await patient.submitPayment(
        appointmentId: apt.id,
        methodId: 'wave',
        receipt: const UploadFile(name: 'recu.jpg', bytes: [1, 2, 3]),
      );
      expect(paid.status, AppointmentStatus.paymentSubmitted);

      final dashboard = await DoctorRepository(api).dashboard();
      expect(
        dashboard.pendingPayments.map((p) => p.patientName),
        contains('Amina Koné'),
      );
      expect(dashboard.stats.today, 8);
      expect(dashboard.stats.toConfirm, 2);
    });

    test('availability summary matches screen (14/day, 56/week)', () async {
      token = 'mock-token-doc_004';
      final saved = await DoctorRepository(api).createAvailability(
        const Availability(
          days: ['Lundi', 'Mardi', 'Mercredi', 'Jeudi'],
          start: '09:00',
          end: '17:30',
          lunchEnabled: true,
          lunchStart: '12:30',
          lunchEnd: '14:00',
          slotDuration: 30,
          location: 'cabinet',
        ),
      );
      expect(saved.slotsPerDay, 14);
      expect(saved.slotsPerWeek, 56);
    });
  });
}
