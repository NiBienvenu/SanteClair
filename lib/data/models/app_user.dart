enum UserRole {
  patient,
  doctor;

  static UserRole fromJson(String? value) =>
      value == 'doctor' ? UserRole.doctor : UserRole.patient;
}

class AppUser {
  const AppUser({
    required this.id,
    required this.role,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    this.verified = false,
    this.specialty,
    this.bloodGroup,
  });

  final String id;
  final UserRole role;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final bool verified;
  final String? specialty;
  final String? bloodGroup;

  String get fullName => '$firstName $lastName';
  String get displayName =>
      role == UserRole.doctor ? 'Dr. $fullName' : fullName;
  String get initials =>
      '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'
          .toUpperCase();

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'] as String,
    role: UserRole.fromJson(json['role'] as String?),
    firstName: json['firstName'] as String? ?? '',
    lastName: json['lastName'] as String? ?? '',
    email: json['email'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    verified: json['verified'] as bool? ?? false,
    specialty: json['specialty'] as String?,
    bloodGroup: json['bloodGroup'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role.name,
    'firstName': firstName,
    'lastName': lastName,
    'email': email,
    'phone': phone,
    'verified': verified,
    'specialty': specialty,
    'bloodGroup': bloodGroup,
  };
}

class AuthSession {
  const AuthSession({
    required this.token,
    required this.user,
    this.refreshToken,
  });

  final String token;
  final String? refreshToken;
  final AppUser user;

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
    token: json['token'] as String,
    refreshToken: json['refresh'] as String?,
    user: AppUser.fromJson(json['user'] as Map<String, dynamic>),
  );

  Map<String, dynamic> toJson() => {
    'token': token,
    'refresh': refreshToken,
    'user': user.toJson(),
  };
}
