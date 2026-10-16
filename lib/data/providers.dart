import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import 'models/app_user.dart';
import 'models/appointment.dart';
import 'models/doctor.dart';
import 'models/doctor_space.dart';
import 'models/patient.dart';
import 'models/referentials.dart';
import 'models/schedule.dart';
import 'repositories/auth_repository.dart';
import 'repositories/doctor_repository.dart';
import 'repositories/patient_repository.dart';
import 'session_storage.dart';

// ------------------------------------------------------------------ infra

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    tokenProvider: () => ref.read(authControllerProvider).session?.token,
    onUnauthorized: () => ref.read(authControllerProvider.notifier).logout(),
    refreshTokenProvider: () =>
        ref.read(authControllerProvider).session?.refreshToken,
    onTokenRefreshed: (token) =>
        ref.read(authControllerProvider.notifier).refreshAccessToken(token),
  );
});

final sessionStorageProvider = Provider((_) => SessionStorage());

final authRepositoryProvider = Provider(
  (ref) => AuthRepository(ref.watch(apiClientProvider)),
);
// The API client is independent of AuthController. Only repositories that
// expose account data are recreated when the signed-in account changes.
final patientRepositoryProvider = Provider((ref) {
  ref.watch(
    authControllerProvider.select(
      (state) => (state.user?.id, state.user?.role),
    ),
  );
  return PatientRepository(ref.watch(apiClientProvider));
});
final doctorRepositoryProvider = Provider((ref) {
  ref.watch(
    authControllerProvider.select(
      (state) => (state.user?.id, state.user?.role),
    ),
  );
  return DoctorRepository(ref.watch(apiClientProvider));
});

// ------------------------------------------------------------------- auth

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  const AuthState(this.status, [this.session]);

  final AuthStatus status;
  final AuthSession? session;

  AppUser? get user => session?.user;
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    Future.microtask(_restore);
    return const AuthState(AuthStatus.unknown);
  }

  SessionStorage get _storage => ref.read(sessionStorageProvider);
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<void> _restore() async {
    final session = await _storage.read();
    state = session == null
        ? const AuthState(AuthStatus.unauthenticated)
        : AuthState(AuthStatus.authenticated, session);
  }

  Future<void> _open(AuthSession session) async {
    await _storage.save(session);
    state = AuthState(AuthStatus.authenticated, session);
  }

  Future<void> login(String identifier, String password, UserRole role) async =>
      _open(
        await _repo.login(
          identifier: identifier,
          password: password,
          role: role,
        ),
      );

  Future<void> biometricLogin(UserRole role) async =>
      _open(await _repo.biometricLogin(role));

  Future<void> registerPatient(PatientSignUp form) async =>
      _open(await _repo.registerPatient(form));

  Future<void> refreshAccessToken(String token) async {
    final current = state.session;
    if (current == null) return;
    await _open(
      AuthSession(
        token: token,
        user: current.user,
        refreshToken: current.refreshToken,
      ),
    );
  }

  Future<void> updateUser(AppUser user) async {
    final current = state.session;
    if (current == null) return;
    await _open(
      AuthSession(
        token: current.token,
        user: user,
        refreshToken: current.refreshToken,
      ),
    );
  }

  Future<void> logout() async {
    await _storage.clear();
    state = const AuthState(AuthStatus.unauthenticated);
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

// ---------------------------------------------------------------- patient

final referentialsProvider = FutureProvider<Referentials>(
  (ref) => ref.watch(patientRepositoryProvider).referentials(),
);

final patientHomeProvider = FutureProvider.autoDispose<PatientHome>(
  (ref) => ref.watch(patientRepositoryProvider).home(),
);

typedef DoctorQuery = ({String query, String? specialty, bool video});

final doctorSearchProvider = FutureProvider.autoDispose
    .family<List<Doctor>, DoctorQuery>(
      (ref, q) => ref
          .watch(patientRepositoryProvider)
          .searchDoctors(
            query: q.query,
            specialty: q.specialty,
            teleconsultation: q.video,
          ),
    );

final doctorProvider = FutureProvider.autoDispose.family<Doctor, String>(
  (ref, id) => ref.watch(patientRepositoryProvider).doctor(id),
);

final doctorSlotsProvider = FutureProvider.autoDispose
    .family<DoctorSchedule, String>(
      (ref, id) => ref.watch(patientRepositoryProvider).doctorSlots(id),
    );

final appointmentsProvider = FutureProvider.autoDispose<List<Appointment>>(
  (ref) => ref.watch(patientRepositoryProvider).appointments(),
);

final appointmentProvider = FutureProvider.autoDispose
    .family<Appointment, String>(
      (ref, id) => ref.watch(patientRepositoryProvider).appointment(id),
    );

final paymentMethodsProvider = FutureProvider.autoDispose<List<PaymentMethod>>(
  (ref) => ref.watch(patientRepositoryProvider).paymentMethods(),
);

final profileProvider = FutureProvider.autoDispose<PatientProfile>(
  (ref) => ref.watch(patientRepositoryProvider).profile(),
);

final medicalRecordProvider = FutureProvider.autoDispose<MedicalRecord>(
  (ref) => ref.watch(patientRepositoryProvider).medicalRecord(),
);

// ----------------------------------------------------------------- doctor

final doctorDashboardProvider = FutureProvider.autoDispose<DoctorDashboard>(
  (ref) => ref.watch(doctorRepositoryProvider).dashboard(),
);

final availabilitiesProvider = FutureProvider.autoDispose<List<Availability>>(
  (ref) => ref.watch(doctorRepositoryProvider).availabilities(),
);

final doctorPatientsProvider = FutureProvider.autoDispose<List<PatientBrief>>(
  (ref) => ref.watch(doctorRepositoryProvider).patients(),
);
