import 'doctor.dart';

enum AppointmentStatus {
  pendingPayment('pending_payment', 'En attente de paiement'),
  paymentSubmitted('payment_submitted', 'Paiement en vérification'),
  confirmed('confirmed', 'Confirmé'),
  completed('completed', 'Terminé'),
  cancelled('cancelled', 'Annulé');

  const AppointmentStatus(this.value, this.label);

  final String value;
  final String label;

  static AppointmentStatus fromJson(String? value) => AppointmentStatus.values
      .firstWhere((s) => s.value == value, orElse: () => pendingPayment);
}

class Appointment {
  const Appointment({
    required this.id,
    required this.patientName,
    required this.doctor,
    required this.date,
    required this.time,
    required this.mode,
    required this.location,
    required this.reason,
    required this.status,
    required this.amount,
    required this.currency,
    this.paymentMethod,
    this.receiptName,
  });

  final String id;
  final String patientName;
  final Doctor doctor;
  final DateTime date;
  final String time;
  final String mode;
  final String location;
  final String reason;
  final AppointmentStatus status;
  final int amount;
  final String currency;
  final String? paymentMethod;
  final String? receiptName;

  bool get isVideo => mode == 'video';

  factory Appointment.fromJson(Map<String, dynamic> json) => Appointment(
    id: json['id'] as String,
    patientName: json['patientName'] as String? ?? '',
    doctor: Doctor.fromJson(json['doctor'] as Map<String, dynamic>),
    date: DateTime.parse(json['date'] as String),
    time: json['time'] as String,
    mode: json['mode'] as String? ?? 'cabinet',
    location: json['location'] as String? ?? '',
    reason: json['reason'] as String? ?? '',
    status: AppointmentStatus.fromJson(json['status'] as String?),
    amount: (json['amount'] as num?)?.toInt() ?? 0,
    currency: json['currency'] as String? ?? 'FBU',
    paymentMethod: json['paymentMethod'] as String?,
    receiptName: json['receiptName'] as String?,
  );
}

class AppointmentRequest {
  const AppointmentRequest({
    required this.doctorId,
    required this.reason,
    required this.date,
    required this.time,
    required this.mode,
  });

  final String doctorId;
  final String reason;
  final String date;
  final String time;
  final String mode;

  Map<String, dynamic> toJson() => {
    'doctorId': doctorId,
    'reason': reason,
    'date': date,
    'time': time,
    'mode': mode,
  };
}
