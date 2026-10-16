import 'doctor.dart';

enum DoctorAvailabilityStatus {
  available('available', 'Disponible'),
  inConsultation('in_consultation', 'En consultation'),
  onBreak('on_break', 'En pause');

  const DoctorAvailabilityStatus(this.value, this.label);

  final String value;
  final String label;

  static DoctorAvailabilityStatus fromJson(String? value) =>
      DoctorAvailabilityStatus.values.firstWhere(
        (s) => s.value == value,
        orElse: () => available,
      );
}

class PatientBrief {
  const PatientBrief({
    required this.name,
    required this.age,
    required this.phone,
    required this.reason,
    this.bloodGroup,
    this.allergies = const [],
    this.lastVisitTime,
    this.mode,
  });

  final String name;
  final int age;
  final String phone;
  final String reason;
  final String? bloodGroup;
  final List<String> allergies;
  final String? lastVisitTime;
  final String? mode;

  factory PatientBrief.fromJson(Map<String, dynamic> json) => PatientBrief(
    name: json['name'] as String? ?? '',
    age: (json['age'] as num?)?.toInt() ?? 0,
    phone: json['phone'] as String? ?? '',
    reason: json['reason'] as String? ?? '',
    bloodGroup: json['bloodGroup'] as String?,
    allergies: List<String>.from(json['allergies'] as List? ?? []),
    lastVisitTime: json['lastVisitTime'] as String?,
    mode: json['mode'] as String?,
  );
}

class ScheduleItem {
  const ScheduleItem({
    required this.id,
    required this.time,
    required this.type,
    required this.status,
    this.mode,
    this.patient,
    this.paid = false,
  });

  final String id;
  final String time;
  final String type;
  final String status;
  final String? mode;
  final PatientBrief? patient;
  final bool paid;

  bool get isFreeSlot => type == 'free';

  factory ScheduleItem.fromJson(Map<String, dynamic> json) => ScheduleItem(
    id: json['id'] as String,
    time: json['time'] as String,
    type: json['type'] as String? ?? 'appointment',
    status: json['status'] as String? ?? 'pending',
    mode: json['mode'] as String?,
    patient: json['patient'] == null
        ? null
        : PatientBrief.fromJson(json['patient'] as Map<String, dynamic>),
    paid: json['paid'] as bool? ?? false,
  );
}

class PendingPayment {
  const PendingPayment({
    required this.id,
    required this.patientName,
    required this.amount,
    required this.currency,
    required this.method,
    required this.time,
    this.receiptName,
    this.receiptUrl,
  });

  final String id;
  final String patientName;
  final int amount;
  final String currency;
  final String method;
  final String time;
  final String? receiptName;
  final String? receiptUrl;

  factory PendingPayment.fromJson(Map<String, dynamic> json) => PendingPayment(
    id: json['id'] as String,
    patientName: json['patientName'] as String? ?? '',
    amount: (json['amount'] as num?)?.toInt() ?? 0,
    currency: json['currency'] as String? ?? 'FBU',
    method: json['method'] as String? ?? '',
    time: json['time'] as String? ?? '',
    receiptName: json['receiptName'] as String?,
    receiptUrl: json['receiptUrl'] as String?,
  );
}

class DashboardStats {
  const DashboardStats({
    required this.today,
    required this.toConfirm,
    required this.teleconsultations,
  });

  final int today;
  final int toConfirm;
  final int teleconsultations;

  factory DashboardStats.fromJson(Map<String, dynamic> json) => DashboardStats(
    today: (json['today'] as num?)?.toInt() ?? 0,
    toConfirm: (json['toConfirm'] as num?)?.toInt() ?? 0,
    teleconsultations: (json['teleconsultations'] as num?)?.toInt() ?? 0,
  );
}

class DoctorDashboard {
  const DoctorDashboard({
    required this.doctor,
    required this.availabilityStatus,
    required this.date,
    required this.stats,
    required this.schedule,
    required this.pendingPayments,
  });

  final Doctor doctor;
  final DoctorAvailabilityStatus availabilityStatus;
  final DateTime date;
  final DashboardStats stats;
  final List<ScheduleItem> schedule;
  final List<PendingPayment> pendingPayments;

  factory DoctorDashboard.fromJson(Map<String, dynamic> json) =>
      DoctorDashboard(
        doctor: Doctor.fromJson(json['doctor'] as Map<String, dynamic>),
        availabilityStatus: DoctorAvailabilityStatus.fromJson(
          json['availabilityStatus'] as String?,
        ),
        date: DateTime.parse(json['date'] as String),
        stats: DashboardStats.fromJson(json['stats'] as Map<String, dynamic>),
        schedule: (json['schedule'] as List)
            .map((e) => ScheduleItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        pendingPayments: (json['pendingPayments'] as List)
            .map((e) => PendingPayment.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class Availability {
  const Availability({
    this.id,
    required this.days,
    required this.start,
    required this.end,
    required this.lunchEnabled,
    required this.lunchStart,
    required this.lunchEnd,
    required this.slotDuration,
    required this.location,
    this.slotsPerDay = 0,
    this.slotsPerWeek = 0,
  });

  final String? id;
  final List<String> days;
  final String start;
  final String end;
  final bool lunchEnabled;
  final String lunchStart;
  final String lunchEnd;
  final int slotDuration;
  final String location;
  final int slotsPerDay;
  final int slotsPerWeek;

  factory Availability.fromJson(Map<String, dynamic> json) {
    final lunch = json['lunchBreak'] as Map<String, dynamic>? ?? {};
    return Availability(
      id: json['id'] as String?,
      days: List<String>.from(json['days'] as List),
      start: json['start'] as String,
      end: json['end'] as String,
      lunchEnabled: lunch['enabled'] as bool? ?? false,
      lunchStart: lunch['start'] as String? ?? '12:30',
      lunchEnd: lunch['end'] as String? ?? '14:00',
      slotDuration: (json['slotDuration'] as num).toInt(),
      location: json['location'] as String? ?? 'cabinet',
      slotsPerDay: (json['slotsPerDay'] as num?)?.toInt() ?? 0,
      slotsPerWeek: (json['slotsPerWeek'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'days': days,
    'start': start,
    'end': end,
    'lunchBreak': {
      'enabled': lunchEnabled,
      'start': lunchStart,
      'end': lunchEnd,
    },
    'slotDuration': slotDuration,
    'location': location,
  };
}
