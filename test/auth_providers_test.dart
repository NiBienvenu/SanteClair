import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sante_clair/core/network/mock/mock_interceptor.dart';
import 'package:sante_clair/data/models/app_user.dart';
import 'package:sante_clair/data/providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'login through the real provider graph does not create a dependency cycle',
    () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);
      // Keep the actual providers: replacing ApiClient would hide this regression.
      container.read(authRepositoryProvider);
      final api = container.read(apiClientProvider);
      api.dio.interceptors.add(MockInterceptor());
      addTearDown(() => api.dio.close());
      await Future<void>.delayed(Duration.zero);
      await container
          .read(authControllerProvider.notifier)
          .login('amina.kone@email.com', 'Sante@2024', UserRole.patient);
      expect(container.read(authControllerProvider).user?.firstName, 'Amina');
      expect(
        (await container.read(profileProvider.future)).email,
        'amina.kone@email.com',
      );

      final patientRepository = container.read(patientRepositoryProvider);
      final doctorRepository = container.read(doctorRepositoryProvider);
      await container.read(authControllerProvider.notifier).logout();
      await container
          .read(authControllerProvider.notifier)
          .login('dr.joubert@cabinet.fr', 'Sante@2024', UserRole.doctor);
      expect(
        container.read(authControllerProvider).user?.role,
        UserRole.doctor,
      );
      expect(identical(container.read(apiClientProvider), api), isTrue);
      expect(
        identical(container.read(patientRepositoryProvider), patientRepository),
        isFalse,
      );
      expect(
        identical(container.read(doctorRepositoryProvider), doctorRepository),
        isFalse,
      );
      expect(
        (await container.read(doctorDashboardProvider.future)).doctor.firstName,
        'Marc',
      );
    },
  );
}
