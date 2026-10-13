import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../models/appointment.dart';
import '../models/doctor.dart';
import '../models/patient.dart';
import '../models/referentials.dart';
import '../models/schedule.dart';

/// Fichier choisi par l'utilisateur, prêt à être envoyé en multipart.
class UploadFile {
  const UploadFile({required this.name, this.path, this.bytes});

  final String name;
  final String? path;
  final List<int>? bytes;

  Future<MultipartFile> toMultipart() async {
    if (bytes != null) return MultipartFile.fromBytes(bytes!, filename: name);
    if (path != null) return MultipartFile.fromFile(path!, filename: name);
    return MultipartFile.fromString('', filename: name);
  }
}

class PatientRepository {
  PatientRepository(this._api);

  final ApiClient _api;

  Future<Referentials> referentials() async =>
      Referentials.fromJson(await _api.get(ApiEndpoints.referentials) as Map<String, dynamic>);

  Future<PatientHome> home() async =>
      PatientHome.fromJson(await _api.get(ApiEndpoints.patientHome) as Map<String, dynamic>);

  Future<List<Doctor>> searchDoctors({
    String? query,
    String? specialty,
    bool teleconsultation = false,
  }) async {
    final data = await _api.get(
      ApiEndpoints.doctors,
      query: {
        if (query != null && query.isNotEmpty) 'q': query,
        'specialty': ?specialty,
        if (teleconsultation) 'teleconsultation': 'true',
      },
    );
    return (data as List)
        .map((e) => Doctor.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Doctor> doctor(String id) async =>
      Doctor.fromJson(await _api.get(ApiEndpoints.doctor(id)) as Map<String, dynamic>);

  Future<DoctorSchedule> doctorSlots(String doctorId) async => DoctorSchedule.fromJson(
    await _api.get(ApiEndpoints.doctorSlots(doctorId)) as Map<String, dynamic>,
  );

  Future<List<Appointment>> appointments() async {
    final data = await _api.get(ApiEndpoints.appointments);
    return (data as List)
        .map((e) => Appointment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Appointment> appointment(String id) async => Appointment.fromJson(
    await _api.get(ApiEndpoints.appointment(id)) as Map<String, dynamic>,
  );

  Future<Appointment> createAppointment(AppointmentRequest request) async =>
      Appointment.fromJson(
        await _api.post(ApiEndpoints.appointments, data: request.toJson())
            as Map<String, dynamic>,
      );

  Future<Appointment> rescheduleAppointment(
    String id,
    AppointmentRequest request,
  ) async => Appointment.fromJson(
    await _api.patch(ApiEndpoints.appointment(id), data: request.toJson())
        as Map<String, dynamic>,
  );

  Future<void> cancelAppointment(String id) =>
      _api.delete(ApiEndpoints.appointment(id));

  Future<List<PaymentMethod>> paymentMethods() async {
    final data = await _api.get(ApiEndpoints.paymentMethods);
    return (data as List)
        .map((e) => PaymentMethod.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Appointment> submitPayment({
    required String appointmentId,
    required String methodId,
    required UploadFile receipt,
  }) async {
    final data = await _api.post(
      ApiEndpoints.appointmentPayment(appointmentId),
      data: FormData.fromMap({
        'method': methodId,
        'receipt': await receipt.toMultipart(),
      }),
    );
    return Appointment.fromJson(data as Map<String, dynamic>);
  }

  Future<PatientProfile> profile() async =>
      PatientProfile.fromJson(await _api.get(ApiEndpoints.profile) as Map<String, dynamic>);

  Future<PatientProfile> updateProfile(Map<String, dynamic> changes) async =>
      PatientProfile.fromJson(
        await _api.put(ApiEndpoints.profile, data: changes) as Map<String, dynamic>,
      );

  Future<MedicalRecord> medicalRecord() async => MedicalRecord.fromJson(
    await _api.get(ApiEndpoints.medicalRecord) as Map<String, dynamic>,
  );

  Future<MedicalDocument> uploadDocument(UploadFile file) async {
    final data = await _api.post(
      ApiEndpoints.medicalDocuments,
      data: FormData.fromMap({'file': await file.toMultipart()}),
    );
    return MedicalDocument.fromJson(data as Map<String, dynamic>);
  }
}
