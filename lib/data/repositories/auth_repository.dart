import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../models/app_user.dart';

class PatientSignUp {
  const PatientSignUp({
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.email,
    required this.password,
    required this.acceptTerms,
    this.bloodGroup,
  });

  final String firstName;
  final String lastName;
  final String phone;
  final String email;
  final String password;
  final bool acceptTerms;
  final String? bloodGroup;

  Map<String, dynamic> toJson() => {
    'firstName': firstName,
    'lastName': lastName,
    'phone': phone,
    'email': email,
    'password': password,
    'bloodGroup': bloodGroup,
    'acceptTerms': acceptTerms,
  };
}

class DoctorSignUp {
  const DoctorSignUp({
    required this.fullName,
    required this.specialty,
    required this.licenseNumber,
    required this.phone,
    required this.email,
    required this.fee,
    required this.password,
    required this.cardFileName,
    this.cardFilePath,
    this.cardBytes,
  });

  final String fullName;
  final String specialty;
  final String licenseNumber;
  final String phone;
  final String email;
  final int fee;
  final String password;
  final String cardFileName;
  final String? cardFilePath;
  final List<int>? cardBytes;
}

class AuthRepository {
  AuthRepository(this._api);

  final ApiClient _api;

  Future<AuthSession> login({
    required String identifier,
    required String password,
    required UserRole role,
  }) async {
    final data = await _api.post(
      ApiEndpoints.login,
      data: {'identifier': identifier, 'password': password, 'role': role.name},
    );
    return AuthSession.fromJson(data as Map<String, dynamic>);
  }

  Future<AuthSession> biometricLogin(UserRole role) async {
    final data = await _api.post(
      ApiEndpoints.biometricLogin,
      data: {'role': role.name},
    );
    return AuthSession.fromJson(data as Map<String, dynamic>);
  }

  Future<String> forgotPassword(String identifier) async {
    final data = await _api.post(
      ApiEndpoints.forgotPassword,
      data: {'identifier': identifier},
    );
    return (data as Map)['message'] as String;
  }

  Future<AuthSession> registerPatient(PatientSignUp form) async {
    final data = await _api.post(
      ApiEndpoints.registerPatient,
      data: form.toJson(),
    );
    return AuthSession.fromJson(data as Map<String, dynamic>);
  }

  Future<String> registerDoctor(DoctorSignUp form) async {
    final MultipartFile card;
    if (form.cardBytes != null) {
      card = MultipartFile.fromBytes(form.cardBytes!, filename: form.cardFileName);
    } else if (form.cardFilePath != null) {
      card = await MultipartFile.fromFile(
        form.cardFilePath!,
        filename: form.cardFileName,
      );
    } else {
      card = MultipartFile.fromString('', filename: form.cardFileName);
    }
    final data = await _api.post(
      ApiEndpoints.registerDoctor,
      data: FormData.fromMap({
        'fullName': form.fullName,
        'specialty': form.specialty,
        'licenseNumber': form.licenseNumber,
        'phone': form.phone,
        'email': form.email,
        'fee': form.fee.toString(),
        'password': form.password,
        'professionalCard': card,
      }),
    );
    return (data as Map)['message'] as String;
  }
}
