class ApiEndpoints {
  static const login = '/auth/login';
  static const biometricLogin = '/auth/biometric';
  static const forgotPassword = '/auth/forgot-password';
  static const registerPatient = '/auth/register/patient';
  static const registerDoctor = '/auth/register/doctor';

  static const referentials = '/referentials';

  static const patientHome = '/patient/home';
  static const doctors = '/doctors';
  static String doctor(String id) => '/doctors/$id';
  static String doctorSlots(String id) => '/doctors/$id/slots';

  static const appointments = '/appointments';
  static String appointment(String id) => '/appointments/$id';
  static String appointmentPayment(String id) => '/appointments/$id/payment';
  static const paymentMethods = '/payment-methods';

  static const profile = '/profile';
  static const medicalRecord = '/medical-record';
  static const medicalDocuments = '/medical-record/documents';

  static const doctorDashboard = '/doctor/dashboard';
  static const doctorStatus = '/doctor/status';
  static String doctorAppointment(String id) => '/doctor/appointments/$id';
  static String validatePayment(String id) => '/doctor/payments/$id/validate';
  static const doctorAvailabilities = '/doctor/availabilities';
  static const doctorPatients = '/doctor/patients';
}
