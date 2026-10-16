import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sante_clair/core/network/api_client.dart';
import 'package:sante_clair/core/theme/app_theme.dart';
import 'package:sante_clair/data/models/appointment.dart';
import 'package:sante_clair/data/models/doctor.dart';
import 'package:sante_clair/data/models/referentials.dart';
import 'package:sante_clair/data/models/schedule.dart';
import 'package:sante_clair/data/providers.dart';
import 'package:sante_clair/data/repositories/patient_repository.dart';
import 'package:sante_clair/features/patient/booking_screen.dart';

const doctor = Doctor(
  id: 'new-video-doctor',
  firstName: 'Nouveau',
  lastName: 'Médecin',
  specialty: 'Médecine générale',
  specialtyKey: 'generaliste',
  fee: 20000,
  currency: 'FBU',
  verified: true,
  teleconsultation: true,
  address: 'Bujumbura',
  cabinetName: 'Cabinet',
  phone: '12345678',
);
const references = Referentials(
  specialties: ['Médecine générale'],
  bloodGroups: ['O+'],
  consultationReasons: [
    OptionItem(id: 'classic', label: 'Consultation classique'),
  ],
  consultationModes: [
    OptionItem(id: 'cabinet', label: 'Au cabinet', icon: 'hospital'),
    OptionItem(id: 'video', label: 'En vidéo', icon: 'video'),
  ],
  weekDays: ['Lundi'],
  slotDurations: [30],
  availabilityLocations: [],
);

class RecordingRepository extends PatientRepository {
  RecordingRepository(super.api);
  AppointmentRequest? submitted;

  @override
  Future<Appointment> createAppointment(AppointmentRequest request) async {
    submitted = request;
    return Appointment(
      id: 'new-appointment',
      patientName: 'Patient',
      doctor: doctor,
      date: DateTime.parse(request.date),
      time: request.time,
      mode: request.mode,
      location: 'Téléconsultation',
      reason: request.reason,
      status: AppointmentStatus.pendingPayment,
      amount: 20000,
      currency: 'FBU',
    );
  }
}

Future<RecordingRepository> renderBooking(
  WidgetTester tester, {
  bool available = true,
  bool empty = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(464, 1100);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  final api = ApiClient(useMock: false, tokenProvider: () => null);
  addTearDown(() => api.dio.close());
  final repo = RecordingRepository(api);
  final schedule = DoctorSchedule(
    monthLabel: 'Janvier 2030',
    days: [
      SlotDay(
        date: '2030-01-07',
        weekday: 'Lun',
        day: 7,
        morning: empty
            ? []
            : [TimeSlot(time: '09:00', available: available, mode: 'video')],
        afternoon: [],
      ),
    ],
  );
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => BookingScreen(doctorId: doctor.id),
      ),
      GoRoute(
        path: '/patient/payment/:id',
        builder: (_, _) =>
            const Scaffold(body: Text('Paiement du rendez-vous')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        doctorProvider.overrideWith((ref, id) async => doctor),
        doctorSlotsProvider.overrideWith((ref, id) async => schedule),
        referentialsProvider.overrideWith((ref) async => references),
        patientRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets(
    'video-only availability can be booked without manually switching mode',
    (tester) async {
      final repo = await renderBooking(tester);
      expect(find.text('09:00'), findsOneWidget);
      final paymentButton = find.ancestor(
        of: find.textContaining('Continuer vers le règlement'),
        matching: find.byType(FilledButton),
      );
      expect(tester.widget<FilledButton>(paymentButton).onPressed, isNotNull);
      await tester.tap(paymentButton);
      await tester.pumpAndSettle();
      expect(repo.submitted?.mode, 'video');
      expect(repo.submitted?.time, '09:00');
      expect(repo.submitted?.doctorId, doctor.id);
      expect(find.text('Paiement du rendez-vous'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('fully booked video schedules explain the unavailable times', (
    tester,
  ) async {
    await renderBooking(tester, available: false);
    expect(
      find.textContaining('Aucun horaire disponible en vidéo'),
      findsOneWidget,
    );
    final button = find.ancestor(
      of: find.textContaining('Continuer vers le règlement'),
      matching: find.byType(FilledButton),
    );
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    expect(find.byTooltip('Actualiser les disponibilités'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a doctor without hours has a clear empty state', (tester) async {
    await renderBooking(tester, empty: true);
    expect(
      find.textContaining('Aucun créneau n’est encore proposé'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
