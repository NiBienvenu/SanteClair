class Doctor {
  const Doctor({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.specialty,
    required this.specialtyKey,
    required this.fee,
    required this.currency,
    required this.verified,
    required this.teleconsultation,
    required this.address,
    required this.cabinetName,
    required this.phone,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String specialty;
  final String specialtyKey;
  final int fee;
  final String currency;
  final bool verified;
  final bool teleconsultation;
  final String address;
  final String cabinetName;
  final String phone;

  String get displayName => 'Dr. $firstName $lastName';
  String get initials => '${firstName[0]}${lastName[0]}'.toUpperCase();

  factory Doctor.fromJson(Map<String, dynamic> json) => Doctor(
    id: json['id'] as String,
    firstName: json['firstName'] as String? ?? '',
    lastName: json['lastName'] as String? ?? '',
    specialty: json['specialty'] as String? ?? '',
    specialtyKey: json['specialtyKey'] as String? ?? '',
    fee: (json['fee'] as num?)?.toInt() ?? 0,
    currency: json['currency'] as String? ?? 'FBU',
    verified: json['verified'] as bool? ?? false,
    teleconsultation: json['teleconsultation'] as bool? ?? false,
    address: json['address'] as String? ?? '',
    cabinetName: json['cabinetName'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'firstName': firstName,
    'lastName': lastName,
    'specialty': specialty,
    'specialtyKey': specialtyKey,
    'fee': fee,
    'currency': currency,
    'verified': verified,
    'teleconsultation': teleconsultation,
    'address': address,
    'cabinetName': cabinetName,
    'phone': phone,
  };
}
