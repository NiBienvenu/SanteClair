import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sante_clair/data/providers.dart';
import 'package:sante_clair/core/network/api_client.dart';
import 'package:sante_clair/data/models/app_user.dart';
import 'package:sante_clair/data/models/appointment.dart';
import 'package:sante_clair/data/models/doctor_space.dart';
import 'package:sante_clair/data/repositories/auth_repository.dart';
import 'package:sante_clair/data/repositories/doctor_repository.dart';
import 'package:sante_clair/data/repositories/patient_repository.dart';

void main() {
  test(
    'Flutter repositories exchange complete data with the real Django API',
    () async {
      String? token;
      String? refresh;
      final api = ApiClient(
        useMock: false,
        tokenProvider: () => token,
        refreshTokenProvider: () => refresh,
        onTokenRefreshed: (value) async => token = value,
      );
      final auth = AuthRepository(api);
      final patient = PatientRepository(api);
      final practitioner = DoctorRepository(api);
      final session = await auth.registerPatient(
        const PatientSignUp(
          firstName: 'Amina',
          lastName: 'Koné',
          email: 'patient.contract@example.com',
          phone: '+257 79 222 222',
          password: 'Sante@2024',
          bloodGroup: 'O+',
          acceptTerms: true,
        ),
      );
      token = session.token;
      refresh = session.refreshToken;
      expect(refresh, isNotNull);
      expect((await patient.profile()).firstName, 'Amina');
      expect((await patient.medicalRecord()).bloodGroup, 'O+');
      expect((await patient.home()).nextAppointment, isNull);
      final refs = await patient.referentials();
      expect(refs.specialtyOptions.single.id, 'generaliste');
      final doctors = await patient.searchDoctors(
        specialty: 'generaliste',
        teleconsultation: true,
      );
      final doctor = await patient.doctor(doctors.single.id);
      expect(doctor.cabinetName, 'Cabinet de test');
      final schedule = await patient.doctorSlots(doctor.id);
      final tomorrow = schedule.days[1];
      final appointment = await patient.createAppointment(
        AppointmentRequest(
          doctorId: doctor.id,
          reason: refs.consultationReasons.first.label,
          date: tomorrow.date,
          time: tomorrow.morning.first.time,
          mode: 'cabinet',
        ),
      );
      expect(appointment.status, AppointmentStatus.pendingPayment);
      final methods = await patient.paymentMethods();
      // Exercise a real multipart replay after an expired JWT.
      token = 'expired-access-token';
      final paid = await patient.submitPayment(
        appointmentId: appointment.id,
        methodId: methods.single.id,
        receipt: const UploadFile(
          name: 'receipt.pdf',
          bytes: [37, 80, 68, 70, 45, 49, 46, 52],
        ),
      );
      expect(paid.receiptName, 'receipt.pdf');
      expect(paid.status, AppointmentStatus.paymentSubmitted);
      final updated = await patient.updateProfile({
        'phone': '+257 79 333 333',
        'birthDate': '1992-05-14',
        'socialSecurityNumber': 'SS-001',
        'settings': {'notificationsEnabled': false},
        'emergencyContact': {
          'name': 'Moussa',
          'relation': 'Frère',
          'phone': '+257 79 444 444',
        },
      });
      expect(updated.emergencyContact?.name, 'Moussa');
      expect(updated.socialSecurityNumber, 'SS-001');
      expect(updated.settings.notificationsEnabled, isFalse);
      final document = await patient.uploadDocument(
        const UploadFile(name: 'record.pdf', bytes: [37, 80, 68, 70]),
      );
      expect(document.fileUrl, isNotNull);
      expect(await api.getBytes(document.fileUrl!), [37, 80, 68, 70]);
      expect(
        (await patient.medicalRecord()).documents.single.fileName,
        'record.pdf',
      );

      final doctorSession = await auth.login(
        identifier: 'doctor.contract@example.com',
        password: 'Sante@2024',
        role: UserRole.doctor,
      );
      token = doctorSession.token;
      refresh = doctorSession.refreshToken;
      final dashboard = await practitioner.dashboard();
      expect(dashboard.doctor.id, doctor.id);
      expect(dashboard.pendingPayments.single.receiptUrl, isNotNull);
      expect(
        (await api.getBytes(dashboard.pendingPayments.single.receiptUrl!))
            .length,
        8,
      );
      expect((await practitioner.patients()).single.bloodGroup, 'O+');
      await practitioner.validatePayment(dashboard.pendingPayments.single.id);
      expect((await practitioner.dashboard()).pendingPayments, isEmpty);
      await practitioner.updateStatus(DoctorAvailabilityStatus.onBreak);
      expect(
        (await practitioner.dashboard()).availabilityStatus,
        DoctorAvailabilityStatus.onBreak,
      );
      expect((await practitioner.availabilities()).single.slotsPerDay, 14);
      final created = await practitioner.createAvailability(
        const Availability(
          days: ['Lundi'],
          start: '18:00',
          end: '20:00',
          lunchEnabled: false,
          lunchStart: '18:30',
          lunchEnd: '19:00',
          slotDuration: 30,
          location: 'video',
        ),
      );
      expect(created.slotsPerWeek, 4);

      token = session.token;
      refresh = session.refreshToken;
      expect(
        (await patient.appointment(appointment.id)).status,
        AppointmentStatus.confirmed,
      );
      expect((await patient.home()).nextAppointment?.id, appointment.id);
      final rescheduled = await patient.rescheduleAppointment(
        appointment.id,
        AppointmentRequest(
          doctorId: doctor.id,
          reason: 'Renouvellement',
          date: tomorrow.date,
          time: tomorrow.morning[1].time,
          mode: 'video',
        ),
      );
      expect(rescheduled.mode, 'video');
      await patient.cancelAppointment(appointment.id);
      expect(
        (await patient.appointments()).single.status,
        AppointmentStatus.cancelled,
      );
      api.dio.close();
    },
    skip: !const bool.fromEnvironment('RUN_BACKEND_CONTRACT'),
  );
  test(
    'authentication providers connect to the real backend without a cycle',
    () async {
      final previousHttpOverrides = HttpOverrides.current;
      TestWidgetsFlutterBinding.ensureInitialized();
      // This opt-in integration test explicitly connects to the local server.
      HttpOverrides.global = null;
      addTearDown(() => HttpOverrides.global = previousHttpOverrides);
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(authRepositoryProvider);
      final api = container.read(apiClientProvider);
      addTearDown(() => api.dio.close());
      await Future<void>.delayed(Duration.zero);
      await container
          .read(authControllerProvider.notifier)
          .login('doctor.contract@example.com', 'Sante@2024', UserRole.doctor);
      expect(
        container.read(authControllerProvider).user?.email,
        'doctor.contract@example.com',
      );
      final dashboard = await container.read(doctorDashboardProvider.future);
      expect(dashboard.doctor.firstName, 'Marc');
      expect(
        dashboard.doctor.id,
        container.read(authControllerProvider).user?.id,
      );
    },
    skip: !const bool.fromEnvironment('RUN_BACKEND_CONTRACT'),
  );
}
