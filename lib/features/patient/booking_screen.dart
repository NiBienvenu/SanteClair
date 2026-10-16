import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_icons.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_bars.dart';
import '../../core/widgets/common.dart';
import '../../data/models/appointment.dart';
import '../../data/models/doctor.dart';
import '../../data/models/referentials.dart';
import '../../data/models/schedule.dart';
import '../../data/providers.dart';
import '../../router/app_router.dart';

class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({
    super.key,
    required this.doctorId,
    this.rescheduleAppointmentId,
  });

  final String doctorId;
  final String? rescheduleAppointmentId;

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  String? _reasonId;
  int? _dayIndex;
  String? _time;
  String? _mode;
  bool _submitting = false;

  bool get _isReschedule => widget.rescheduleAppointmentId != null;

  void _retry() {
    ref.invalidate(doctorProvider(widget.doctorId));
    ref.invalidate(doctorSlotsProvider(widget.doctorId));
    ref.invalidate(referentialsProvider);
    if (_isReschedule) {
      ref.invalidate(appointmentProvider(widget.rescheduleAppointmentId!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final doctor = ref.watch(doctorProvider(widget.doctorId));
    final slots = ref.watch(doctorSlotsProvider(widget.doctorId));
    final refs = ref.watch(referentialsProvider);
    final existing = _isReschedule
        ? ref.watch(appointmentProvider(widget.rescheduleAppointmentId!))
        : const AsyncValue<Appointment?>.data(null);

    final values = <AsyncValue<Object?>>[doctor, slots, refs, existing];
    final failed = values.where((v) => v.hasError && !v.isLoading).firstOrNull;
    final ready = values.every((v) => v.hasValue);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: BackAppBar(
        title: _isReschedule
            ? 'Modifier le rendez-vous'
            : 'Réservation Praticien',
        onClose: () => context.go(Routes.patientHome),
        trailing: IconButton(
          tooltip: 'Actualiser les disponibilités',
          onPressed: _retry,
          icon: const Icon(Icons.refresh),
        ),
      ),
      body: failed != null
          ? AsyncValueView<Object?>(
              value: failed,
              onRetry: _retry,
              builder: (_) => const SizedBox(),
            )
          : !ready
          ? const Center(child: CircularProgressIndicator())
          : _buildForm(
              doctor.requireValue,
              slots.requireValue,
              refs.requireValue,
              existing.value,
            ),
    );
  }

  Widget _buildForm(
    Doctor doctor,
    DoctorSchedule schedule,
    Referentials refs,
    Appointment? existing,
  ) {
    final reasons = refs.consultationReasons;
    final reasonId =
        _reasonId ??
        reasons.where((r) => r.label == existing?.reason).firstOrNull?.id ??
        reasons.first.id;
    bool matchesMode(TimeSlot slot, String value) =>
        (slot.mode == 'both' || slot.mode == value) &&
        (value != 'video' || doctor.teleconsultation);
    bool ownSlot(SlotDay day, TimeSlot slot) =>
        existing != null &&
        day.date == existing.date.toIso8601String().substring(0, 10) &&
        slot.time == existing.time;
    final availableModes = [
      for (final mode in refs.consultationModes)
        if (schedule.days.any(
          (day) => [...day.morning, ...day.afternoon].any(
            (slot) =>
                (slot.available || ownSlot(day, slot)) &&
                matchesMode(slot, mode.id),
          ),
        ))
          mode.id,
    ];
    final offeredModes = [
      for (final mode in refs.consultationModes)
        if (schedule.days.any(
          (day) => [
            ...day.morning,
            ...day.afternoon,
          ].any((slot) => matchesMode(slot, mode.id)),
        ))
          mode.id,
    ];
    final requestedMode = _mode ?? existing?.mode;
    final mode = requestedMode != null && offeredModes.contains(requestedMode)
        ? requestedMode
        : availableModes.firstOrNull ?? offeredModes.firstOrNull ?? 'cabinet';
    bool eligible(SlotDay day, TimeSlot slot) =>
        (slot.available || ownSlot(day, slot)) && matchesMode(slot, mode);

    bool eligibleDay(SlotDay day) =>
        [...day.morning, ...day.afternoon].any((s) => eligible(day, s));
    final existingDay = schedule.days.indexWhere(
      (d) =>
          existing != null &&
          d.date == existing.date.toIso8601String().substring(0, 10) &&
          eligibleDay(d),
    );
    final suggestedDay = existingDay >= 0
        ? existingDay
        : schedule.days.indexWhere(eligibleDay);
    final requestedDay = _dayIndex;
    final dayIndex =
        requestedDay != null &&
            requestedDay < schedule.days.length &&
            eligibleDay(schedule.days[requestedDay])
        ? requestedDay
        : suggestedDay;
    final day = dayIndex >= 0 ? schedule.days[dayIndex] : null;
    final validSlots = day == null
        ? <TimeSlot>[]
        : [
            ...day.morning,
            ...day.afternoon,
          ].where((s) => eligible(day, s)).toList();
    final requestedTime = _time ?? (_dayIndex == null ? existing?.time : null);
    final time = validSlots.any((s) => s.time == requestedTime)
        ? requestedTime
        : validSlots.firstOrNull?.time;
    final reason = reasons.firstWhere((r) => r.id == reasonId);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              _DoctorHeader(doctor: doctor),
              const SizedBox(height: 14),
              const NumberedSection(
                number: 1,
                title: 'Motif',
                trailing: Text(
                  'Obligatoire',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 3.2,
                children: [
                  for (final r in reasons)
                    SelectTile(
                      selected: r.id == reasonId,
                      onTap: () => setState(() => _reasonId = r.id),
                      child: Row(
                        children: [
                          Icon(
                            iconFor(r.icon),
                            color: r.id == 'emergency' && r.id != reasonId
                                ? AppColors.danger
                                : null,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              r.label,
                              style: const TextStyle(fontSize: 12.5),
                              maxLines: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              NumberedSection(
                number: 2,
                title: 'Choisir le jour',
                trailing: Text(
                  schedule.monthLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var i = 0; i < schedule.days.length; i++)
                      SizedBox(
                        width: 68,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: SelectTile(
                            selected: i == dayIndex,
                            enabled: eligibleDay(schedule.days[i]),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            onTap: () => setState(() {
                              _dayIndex = i;
                              _time = null;
                            }),
                            child: Column(
                              children: [
                                Text(
                                  schedule.days[i].weekday,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${schedule.days[i].day}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const NumberedSection(number: 3, title: 'Choisir l\'heure'),
              if (day == null)
                InfoBanner(
                  icon: Icons.event_busy_outlined,
                  text: offeredModes.isEmpty
                      ? 'Aucun créneau n’est encore proposé par ce médecin. Actualisez les disponibilités ou choisissez un autre praticien.'
                      : 'Aucun horaire disponible ${mode == 'video' ? 'en vidéo' : 'au cabinet'} sur les prochains jours. Essayez un autre mode ou actualisez les disponibilités.',
                ),
              if (day != null) ...[
                _SlotRow(
                  label: 'MATIN',
                  icon: Icons.wb_sunny_outlined,
                  slots: day.morning
                      .map(
                        (s) => TimeSlot(
                          time: s.time,
                          available: eligible(day, s),
                          mode: s.mode,
                        ),
                      )
                      .toList(),
                  selected: time,
                  onSelect: (t) => setState(() => _time = t),
                ),
                const SizedBox(height: 10),
                _SlotRow(
                  label: 'APRÈS-MIDI',
                  icon: Icons.wb_twilight_outlined,
                  slots: day.afternoon
                      .map(
                        (s) => TimeSlot(
                          time: s.time,
                          available: eligible(day, s),
                          mode: s.mode,
                        ),
                      )
                      .toList(),
                  selected: time,
                  onSelect: (t) => setState(() => _time = t),
                ),
              ],
              const SizedBox(height: 14),
              const NumberedSection(number: 4, title: 'Mode de consultation'),
              Row(
                children: [
                  for (final m in refs.consultationModes)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: SelectTile(
                          selected: m.id == mode,
                          enabled: offeredModes.contains(m.id),
                          padding: const EdgeInsets.all(12),
                          onTap: () => setState(() {
                            _mode = m.id;
                            _time = null;
                            _dayIndex = null;
                          }),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(iconFor(m.icon)),
                              const SizedBox(height: 8),
                              Text(m.label),
                              Text(
                                m.subtitle ?? '',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const InfoBanner(
                icon: Icons.shield_outlined,
                text: 'Votre paiement sera vérifié avant confirmation du rendez-vous.',
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: PrimaryButton(
              label: _isReschedule
                  ? 'Confirmer la modification'
                  : 'Continuer vers le règlement (${formatMoney(doctor.fee, doctor.currency)})',
              trailingIcon: Icons.arrow_forward,
              loading: _submitting,
              onPressed: day == null || time == null
                  ? null
                  : () => _submit(
                      AppointmentRequest(
                        doctorId: doctor.id,
                        reason: reason.label,
                        date: day.date,
                        time: time,
                        mode: mode,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _submit(AppointmentRequest request) async {
    setState(() => _submitting = true);
    final repo = ref.read(patientRepositoryProvider);
    try {
      if (_isReschedule) {
        await repo.rescheduleAppointment(
          widget.rescheduleAppointmentId!,
          request,
        );
        ref
          ..invalidate(patientHomeProvider)
          ..invalidate(appointmentsProvider);
        if (!mounted) return;
        showAppSnack(context, 'Rendez-vous modifié avec succès.');
        context.pop();
      } else {
        final appointment = await repo.createAppointment(request);
        ref.invalidate(appointmentsProvider);
        if (!mounted) return;
        await context.push(Routes.payment(appointment.id));
        ref.invalidate(doctorSlotsProvider(widget.doctorId));
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppSnack(context, e.message, error: true);
      if (e.statusCode == 409) {
        setState(() => _time = null);
        ref.invalidate(doctorSlotsProvider(widget.doctorId));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _DoctorHeader extends StatelessWidget {
  const _DoctorHeader({required this.doctor});

  final Doctor doctor;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      color: AppColors.surfaceSoft,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surfaceTint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.medical_services_outlined,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        doctor.displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    if (doctor.verified) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.verified,
                        size: 16,
                        color: AppColors.success,
                      ),
                    ],
                  ],
                ),
                Text(
                  doctor.specialty,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                StatusBadge(
                  label: 'Tarif : ${formatMoney(doctor.fee, doctor.currency)}',
                  icon: Icons.payments_outlined,
                  color: AppColors.primary,
                  background: AppColors.surfaceTint,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SlotRow extends StatelessWidget {
  const _SlotRow({
    required this.label,
    required this.icon,
    required this.slots,
    required this.selected,
    required this.onSelect,
  });

  final String label;
  final IconData icon;
  final List<TimeSlot> slots;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 8,
          children: [
            for (final s in slots)
              SizedBox(
                width: 76,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: SelectTile(
                    selected: s.time == selected,
                    enabled: s.available,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    onTap: () => onSelect(s.time),
                    child: Center(child: Text(s.time)),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
