import 'appointment.dart';
import 'doctor.dart';
import 'referentials.dart';

class PatientHome {
  const PatientHome({
    required this.firstName,
    required this.subtitle,
    required this.verified,
    required this.nextAppointment,
    required this.quickConsultations,
    required this.recentDoctors,
  });

  final String firstName;
  final String subtitle;
  final bool verified;
  final Appointment? nextAppointment;
  final List<OptionItem> quickConsultations;
  final List<Doctor> recentDoctors;

  factory PatientHome.fromJson(Map<String, dynamic> json) => PatientHome(
    firstName: json['firstName'] as String? ?? '',
    subtitle: json['subtitle'] as String? ?? '',
    verified: json['verified'] as bool? ?? false,
    nextAppointment: json['nextAppointment'] == null
        ? null
        : Appointment.fromJson(json['nextAppointment'] as Map<String, dynamic>),
    quickConsultations: (json['quickConsultations'] as List)
        .map((e) => OptionItem.fromJson(e as Map<String, dynamic>))
        .toList(),
    recentDoctors: (json['recentDoctors'] as List)
        .map((e) => Doctor.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class EmergencyContact {
  const EmergencyContact({
    required this.name,
    required this.relation,
    required this.phone,
  });

  final String name;
  final String relation;
  final String phone;

  factory EmergencyContact.fromJson(Map<String, dynamic> json) =>
      EmergencyContact(
        name: json['name'] as String? ?? '',
        relation: json['relation'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
    'name': name,
    'relation': relation,
    'phone': phone,
  };
}

class ProfileSettings {
  const ProfileSettings({
    required this.paymentMethodsSummary,
    required this.notificationsSummary,
    required this.notificationsEnabled,
    required this.securitySummary,
    required this.sharingSummary,
    required this.helpSummary,
  });

  final String paymentMethodsSummary;
  final String notificationsSummary;
  final bool notificationsEnabled;
  final String securitySummary;
  final String sharingSummary;
  final String helpSummary;

  factory ProfileSettings.fromJson(Map<String, dynamic> json) =>
      ProfileSettings(
        paymentMethodsSummary: json['paymentMethodsSummary'] as String? ?? '',
        notificationsSummary: json['notificationsSummary'] as String? ?? '',
        notificationsEnabled: json['notificationsEnabled'] as bool? ?? false,
        securitySummary: json['securitySummary'] as String? ?? '',
        sharingSummary: json['sharingSummary'] as String? ?? '',
        helpSummary: json['helpSummary'] as String? ?? '',
      );
}

class PatientProfile {
  const PatientProfile({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.verified,
    required this.dataHosting,
    required this.consentStatus,
    required this.settings,
    this.birthDate,
    this.socialSecurityNumber,
    this.emergencyContact,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final bool verified;
  final String dataHosting;
  final String consentStatus;
  final ProfileSettings settings;
  final DateTime? birthDate;
  final String? socialSecurityNumber;
  final EmergencyContact? emergencyContact;

  String get fullName => '$firstName $lastName';
  String get initials => '${firstName[0]}${lastName[0]}'.toUpperCase();

  factory PatientProfile.fromJson(Map<String, dynamic> json) => PatientProfile(
    id: json['id'] as String,
    firstName: json['firstName'] as String? ?? '',
    lastName: json['lastName'] as String? ?? '',
    email: json['email'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    verified: json['verified'] as bool? ?? false,
    dataHosting: json['dataHosting'] as String? ?? '',
    consentStatus: json['consentStatus'] as String? ?? '',
    settings: ProfileSettings.fromJson(
      json['settings'] as Map<String, dynamic>? ?? {},
    ),
    birthDate: json['birthDate'] == null
        ? null
        : DateTime.parse(json['birthDate'] as String),
    socialSecurityNumber: json['socialSecurityNumber'] as String?,
    emergencyContact: json['emergencyContact'] == null
        ? null
        : EmergencyContact.fromJson(
            json['emergencyContact'] as Map<String, dynamic>,
          ),
  );
}

class MedicalDocument {
  const MedicalDocument({
    required this.id,
    required this.type,
    required this.title,
    required this.date,
    required this.details,
    this.fileName,
  });

  final String id;
  final String type;
  final String title;
  final DateTime date;
  final String details;
  final String? fileName;

  factory MedicalDocument.fromJson(Map<String, dynamic> json) =>
      MedicalDocument(
        id: json['id'] as String,
        type: json['type'] as String? ?? 'document',
        title: json['title'] as String? ?? '',
        date: DateTime.parse(json['date'] as String),
        details: json['details'] as String? ?? '',
        fileName: json['fileName'] as String?,
      );
}

class ConsultationHistory {
  const ConsultationHistory({
    required this.id,
    required this.title,
    required this.doctor,
    required this.place,
    required this.date,
    required this.status,
  });

  final String id;
  final String title;
  final String doctor;
  final String place;
  final DateTime date;
  final String status;

  factory ConsultationHistory.fromJson(Map<String, dynamic> json) =>
      ConsultationHistory(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        doctor: json['doctor'] as String? ?? '',
        place: json['place'] as String? ?? '',
        date: DateTime.parse(json['date'] as String),
        status: json['status'] as String? ?? '',
      );
}

class MedicalRecord {
  const MedicalRecord({
    required this.updatedAt,
    required this.bloodGroup,
    required this.allergies,
    required this.activeTreatments,
    required this.records,
    required this.consultations,
    required this.documents,
    required this.acceptedFormats,
    required this.maxSizeMb,
  });

  final DateTime updatedAt;
  final String? bloodGroup;
  final List<String> allergies;
  final int activeTreatments;
  final List<MedicalDocument> records;
  final List<ConsultationHistory> consultations;
  final List<MedicalDocument> documents;
  final List<String> acceptedFormats;
  final int maxSizeMb;

  factory MedicalRecord.fromJson(Map<String, dynamic> json) => MedicalRecord(
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    bloodGroup: json['bloodGroup'] as String?,
    allergies: List<String>.from(json['allergies'] as List? ?? []),
    activeTreatments: (json['activeTreatments'] as num?)?.toInt() ?? 0,
    records: (json['records'] as List? ?? [])
        .map((e) => MedicalDocument.fromJson(e as Map<String, dynamic>))
        .toList(),
    consultations: (json['consultations'] as List? ?? [])
        .map((e) => ConsultationHistory.fromJson(e as Map<String, dynamic>))
        .toList(),
    documents: (json['documents'] as List? ?? [])
        .map((e) => MedicalDocument.fromJson(e as Map<String, dynamic>))
        .toList(),
    acceptedFormats: List<String>.from(json['acceptedFormats'] as List? ?? []),
    maxSizeMb: (json['maxSizeMb'] as num?)?.toInt() ?? 25,
  );
}
