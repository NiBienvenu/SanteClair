import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../models/doctor_space.dart';

enum ScheduleAction { accept, refuse, block, unblock }

class DoctorRepository {
  DoctorRepository(this._api);

  final ApiClient _api;

  Future<DoctorDashboard> dashboard() async => DoctorDashboard.fromJson(
    await _api.get(ApiEndpoints.doctorDashboard) as Map<String, dynamic>,
  );

  Future<void> updateStatus(DoctorAvailabilityStatus status) =>
      _api.patch(ApiEndpoints.doctorStatus, data: {'status': status.value});

  Future<void> updateScheduleItem(String id, ScheduleAction action) => _api
      .patch(ApiEndpoints.doctorAppointment(id), data: {'action': action.name});

  Future<String> validatePayment(String paymentId) async {
    final data = await _api.post(ApiEndpoints.validatePayment(paymentId));
    return (data as Map)['message'] as String;
  }

  Future<List<Availability>> availabilities() async {
    final data = await _api.get(ApiEndpoints.doctorAvailabilities);
    return (data as List)
        .map((e) => Availability.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Availability> createAvailability(Availability availability) async =>
      Availability.fromJson(
        await _api.post(
              ApiEndpoints.doctorAvailabilities,
              data: availability.toJson(),
            )
            as Map<String, dynamic>,
      );

  Future<List<PatientBrief>> patients() async {
    final data = await _api.get(ApiEndpoints.doctorPatients);
    return (data as List)
        .map((e) => PatientBrief.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
