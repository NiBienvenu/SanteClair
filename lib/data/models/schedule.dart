class TimeSlot {
  const TimeSlot({
    required this.time,
    required this.available,
    this.mode = 'both',
  });

  final String time;
  final bool available;
  final String mode;

  factory TimeSlot.fromJson(Map<String, dynamic> json) => TimeSlot(
    time: json['time'] as String,
    available: json['available'] as bool? ?? true,
    mode: json['mode'] as String? ?? 'both',
  );
}

class SlotDay {
  const SlotDay({
    required this.date,
    required this.weekday,
    required this.day,
    required this.morning,
    required this.afternoon,
  });

  final String date;
  final String weekday;
  final int day;
  final List<TimeSlot> morning;
  final List<TimeSlot> afternoon;

  bool get hasAvailability =>
      morning.any((s) => s.available) || afternoon.any((s) => s.available);

  factory SlotDay.fromJson(Map<String, dynamic> json) => SlotDay(
    date: json['date'] as String,
    weekday: json['weekday'] as String,
    day: (json['day'] as num).toInt(),
    morning: (json['morning'] as List)
        .map((e) => TimeSlot.fromJson(e as Map<String, dynamic>))
        .toList(),
    afternoon: (json['afternoon'] as List)
        .map((e) => TimeSlot.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class DoctorSchedule {
  const DoctorSchedule({required this.monthLabel, required this.days});

  final String monthLabel;
  final List<SlotDay> days;

  factory DoctorSchedule.fromJson(Map<String, dynamic> json) => DoctorSchedule(
    monthLabel: json['monthLabel'] as String? ?? '',
    days: (json['days'] as List)
        .map((e) => SlotDay.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
