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
  const BookingScreen({super.key, required this.doctorId, this.rescheduleAppointmentId});

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
    if (_isReschedule) ref.invalidate(appointmentProvider(widget.rescheduleAppointmentId!));
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
        title: _isReschedule ? 'Modifier le rendez-vous' : 'Réservation Praticien',
        onClose: () => context.go(Routes.patientHome),
      ),
      body: failed != null
          ? AsyncValueView<Object?>(value: failed, onRetry: _retry, builder: (_) => const SizedBox())
          : !ready
          ? const Center(child: CircularProgressIndicator())
          : _buildForm(doctor.requireValue, slots.requireValue, refs.requireValue, existing.value),
    );
  }

  Widget _buildForm(Doctor doctor, DoctorSchedule schedule, Referentials refs, Appointment? existing) {
    final reasons = refs.consultationReasons;
    final reasonId = _reasonId ??
        reasons.where((r) => r.label == existing?.reason).firstOrNull?.id ??
        reasons.first.id;
    final existingDay = schedule.days.indexWhere(
      (d) => existing != null && d.date == existing.date.toIso8601String().substring(0, 10),
    );
    final dayIndex = _dayIndex ??
        (existingDay >= 0 ? existingDay : schedule.days.indexWhere((d) => d.hasAvailability));
    final day = dayIndex >= 0 ? schedule.days[dayIndex] : null;
    final firstFree = day == null
        ? null
        : [...day.morning, ...day.afternoon].where((s) => s.available).firstOrNull?.time;
    final time = _time ?? (_dayIndex == null ? existing?.time : null) ?? firstFree;
    final mode = _mode ?? existing?.mode ?? 'cabinet';
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
                trailing: Text('Obligatoire', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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
                            color: r.id == 'emergency' && r.id != reasonId ? AppColors.danger : null,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(r.label, style: const TextStyle(fontSize: 12.5), maxLines: 2),
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
                trailing: Text(schedule.monthLabel,
                    style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
              ),
              Row(
                children: [
                  for (var i = 0; i < schedule.days.length; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: SelectTile(
                          selected: i == dayIndex,
                          enabled: schedule.days[i].hasAvailability,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          onTap: () => setState(() {
                            _dayIndex = i;
                            _time = null;
                          }),
                          child: Column(
                            children: [
                              Text(schedule.days[i].weekday,
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 2),
                              Text('${schedule.days[i].day}',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              const NumberedSection(number: 3, title: 'Choisir l\'heure'),
              if (day != null) ...[
                _SlotRow(
                  label: 'MATIN',
                  icon: Icons.wb_sunny_outlined,
                  slots: day.morning,
                  selected: time,
                  onSelect: (t) => setState(() => _time = t),
                ),
                const SizedBox(height: 10),
                _SlotRow(
                  label: 'APRÈS-MIDI',
                  icon: Icons.wb_twilight_outlined,
                  slots: day.afternoon,
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
                          enabled: m.id != 'video' || doctor.teleconsultation,
                          padding: const EdgeInsets.all(12),
                          onTap: () => setState(() => _mode = m.id),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(iconFor(m.icon)),
                              const SizedBox(height: 8),
                              Text(m.label),
                              Text(m.subtitle ?? '',
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w400)),
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
                text: 'Données certifiées HDS • Annulation gratuite jusqu\'à 2h avant',
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
                  : () => _submit(AppointmentRequest(
                        doctorId: doctor.id,
                        reason: reason.label,
                        date: day.date,
                        time: time,
                        mode: mode,
                      )),
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
        await repo.rescheduleAppointment(widget.rescheduleAppointmentId!, request);
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
            decoration: BoxDecoration(color: AppColors.surfaceTint, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.medical_services_outlined, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(doctor.displayName,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    ),
                    if (doctor.verified) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified, size: 16, color: AppColors.success),
                    ],
                  ],
                ),
                Text(doctor.specialty, style: const TextStyle(color: AppColors.textSecondary)),
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
            Text(label,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final s in slots)
              Expanded(
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
