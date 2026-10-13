/// Configuration globale de l'application.
///
/// Pour brancher la vraie API :
/// `flutter run --dart-define=USE_MOCK=false --dart-define=API_BASE_URL=https://...`
class AppConfig {
  static const bool useMock = bool.fromEnvironment(
    'USE_MOCK',
    defaultValue: true,
  );

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.santeclair.example/v1',
  );

  static const Duration mockLatency = Duration(milliseconds: 450);

  static const String currency = 'FBU';
  static const String appVersion = 'SantéClair v2.4.1';

  static const String demoPatientEmail = 'amina.kone@email.com';
  static const String demoDoctorEmail = 'dr.joubert@cabinet.fr';
  static const String demoPassword = 'Sante@2024';
}
