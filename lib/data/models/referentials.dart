class OptionItem {
  const OptionItem({
    required this.id,
    required this.label,
    this.subtitle,
    this.icon,
  });

  final String id;
  final String label;
  final String? subtitle;
  final String? icon;

  factory OptionItem.fromJson(Map<String, dynamic> json) => OptionItem(
    id: json['id'] as String,
    label: json['label'] as String,
    subtitle: json['subtitle'] as String?,
    icon: json['icon'] as String?,
  );
}

List<OptionItem> _options(dynamic list) => (list as List? ?? [])
    .map((e) => OptionItem.fromJson(e as Map<String, dynamic>))
    .toList();

class Referentials {
  const Referentials({
    required this.specialties,
    this.specialtyOptions = const [],
    required this.bloodGroups,
    required this.consultationReasons,
    required this.consultationModes,
    required this.weekDays,
    required this.slotDurations,
    required this.availabilityLocations,
  });

  final List<String> specialties;
  final List<OptionItem> specialtyOptions;
  final List<String> bloodGroups;
  final List<OptionItem> consultationReasons;
  final List<OptionItem> consultationModes;
  final List<String> weekDays;
  final List<int> slotDurations;
  final List<OptionItem> availabilityLocations;

  factory Referentials.fromJson(Map<String, dynamic> json) => Referentials(
    specialties: List<String>.from(json['specialties'] as List),
    specialtyOptions: _options(json['specialtyOptions']),
    bloodGroups: List<String>.from(json['bloodGroups'] as List),
    consultationReasons: _options(json['consultationReasons']),
    consultationModes: _options(json['consultationModes']),
    weekDays: List<String>.from(json['weekDays'] as List),
    slotDurations: (json['slotDurations'] as List)
        .map((e) => (e as num).toInt())
        .toList(),
    availabilityLocations: _options(json['availabilityLocations']),
  );
}

class PaymentMethod {
  const PaymentMethod({
    required this.id,
    required this.label,
    this.account,
    this.icon,
  });

  final String id;
  final String label;
  final String? account;
  final String? icon;

  factory PaymentMethod.fromJson(Map<String, dynamic> json) => PaymentMethod(
    id: json['id'] as String,
    label: json['label'] as String,
    account: json['account'] as String?,
    icon: json['icon'] as String?,
  );
}
