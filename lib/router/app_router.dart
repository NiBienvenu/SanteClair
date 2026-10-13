import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/app_shell.dart';
import '../data/models/app_user.dart';
import '../data/providers.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_doctor_screen.dart';
import '../features/auth/register_patient_screen.dart';
import '../features/auth/splash_screen.dart';
import '../features/doctor/add_availability_screen.dart';
import '../features/doctor/doctor_appointments_screen.dart';
import '../features/doctor/doctor_dashboard_screen.dart';
import '../features/doctor/doctor_patients_screen.dart';
import '../features/doctor/doctor_profile_screen.dart';
import '../features/patient/appointments_screen.dart';
import '../features/patient/booking_screen.dart';
import '../features/patient/doctor_search_screen.dart';
import '../features/patient/medical_record_screen.dart';
import '../features/patient/patient_home_screen.dart';
import '../features/patient/payment_screen.dart';
import '../features/patient/profile_screen.dart';

class Routes {
  static const splash = '/splash';
  static const login = '/login';
  static const registerPatient = '/register/patient';
  static const registerDoctor = '/register/doctor';

  static const patientHome = '/patient';
  static const patientAppointments = '/patient/appointments';
  static const patientRecord = '/patient/record';
  static const patientProfile = '/patient/profile';
  static const doctorSearch = '/patient/search';
  static String booking(String doctorId, {String? reschedule}) =>
      '/patient/booking/$doctorId${reschedule == null ? '' : '?reschedule=$reschedule'}';
  static String payment(String appointmentId) => '/patient/payment/$appointmentId';

  static const doctorHome = '/doctor';
  static const doctorAppointments = '/doctor/appointments';
  static const doctorPatients = '/doctor/patients';
  static const doctorProfile = '/doctor/profile';
  static const addAvailability = '/doctor/availability/new';
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<AuthState>(ref.read(authControllerProvider));
  ref.listen(authControllerProvider, (_, next) => refresh.value = next);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final location = state.matchedLocation;
      final onAuthPage = location == Routes.login || location.startsWith('/register');

      if (auth.status == AuthStatus.unknown) {
        return location == Routes.splash ? null : Routes.splash;
      }
      if (auth.status == AuthStatus.unauthenticated) {
        return onAuthPage ? null : Routes.login;
      }
      final home = auth.user!.role == UserRole.doctor ? Routes.doctorHome : Routes.patientHome;
      if (onAuthPage || location == Routes.splash || !location.startsWith(home)) return home;
      return null;
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(path: Routes.registerPatient, builder: (_, _) => const RegisterPatientScreen()),
      GoRoute(path: Routes.registerDoctor, builder: (_, _) => const RegisterDoctorScreen()),

      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(shell: shell),
        branches: [
          _branch(Routes.patientHome, const PatientHomeScreen()),
          _branch(Routes.patientAppointments, const AppointmentsScreen()),
          _branch(Routes.patientRecord, const MedicalRecordScreen()),
          _branch(Routes.patientProfile, const ProfileScreen()),
        ],
      ),
      GoRoute(
        path: Routes.doctorSearch,
        builder: (_, state) => DoctorSearchScreen(
          initialQuery: state.uri.queryParameters['q'] ?? '',
          specialty: state.uri.queryParameters['specialty'],
          video: state.uri.queryParameters['video'] == 'true',
        ),
      ),
      GoRoute(
        path: '/patient/booking/:doctorId',
        builder: (_, state) => BookingScreen(
          doctorId: state.pathParameters['doctorId']!,
          rescheduleAppointmentId: state.uri.queryParameters['reschedule'],
        ),
      ),
      GoRoute(
        path: '/patient/payment/:appointmentId',
        builder: (_, state) =>
            PaymentScreen(appointmentId: state.pathParameters['appointmentId']!),
      ),

      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(shell: shell),
        branches: [
          _branch(Routes.doctorHome, const DoctorDashboardScreen()),
          _branch(Routes.doctorAppointments, const DoctorAppointmentsScreen()),
          _branch(Routes.doctorPatients, const DoctorPatientsScreen()),
          _branch(Routes.doctorProfile, const DoctorProfileScreen()),
        ],
      ),
      GoRoute(
        path: Routes.addAvailability,
        builder: (_, _) => const AddAvailabilityScreen(),
      ),
    ],
  );
});

StatefulShellBranch _branch(String path, Widget screen) => StatefulShellBranch(
  routes: [GoRoute(path: path, builder: (_, _) => screen)],
);
