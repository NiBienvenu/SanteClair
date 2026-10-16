import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_icons.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_bars.dart';
import '../../core/widgets/common.dart';
import '../../data/models/doctor_space.dart';
import '../../data/models/referentials.dart';
import '../../data/providers.dart';

class AddAvailabilityScreen extends ConsumerStatefulWidget {
  const AddAvailabilityScreen({super.key});

  @override
  ConsumerState<AddAvailabilityScreen> createState() =>
      _AddAvailabilityScreenState();
}

class _AddAvailabilityScreenState extends ConsumerState<AddAvailabilityScreen> {
  final Set<String> _days = {'Lundi', 'Mardi', 'Mercredi', 'Jeudi'};
  String _start = '09:00';
  String _end = '17:30';
  bool _lunch = true;
  String _lunchStart = '12:30';
  String _lunchEnd = '14:00';
  int _duration = 30;
  String _location = 'cabinet';
  bool _saving = false;

  String? get _error {
    if (_days.isEmpty) return 'Sélectionnez au moins un jour.';
    final start = minutesOf(_start), end = minutesOf(_end);
    if (end <= start) {
      return 'L\'heure de fin doit être après l\'heure de début.';
    }
    if (_lunch) {
      final ls = minutesOf(_lunchStart), le = minutesOf(_lunchEnd);
      if (le <= ls) return 'La reprise doit être après le début de la pause.';
      if (ls < start || le > end) {
        return 'La pause doit être comprise dans la plage horaire.';
      }
    }
    if (_slotsPerDay == 0) {
      return 'La plage est trop courte pour cette durée de consultation.';
    }
    return null;
  }

  int get _slotsPerDay {
    final start = minutesOf(_start), end = minutesOf(_end);
    if (end <= start) return 0;
    if (!_lunch) return (end - start) ~/ _duration;
    final lunchStart = minutesOf(_lunchStart), lunchEnd = minutesOf(_lunchEnd);
    if (lunchStart < start || lunchEnd > end || lunchEnd <= lunchStart) {
      return 0;
    }
    return (lunchStart - start) ~/ _duration + (end - lunchEnd) ~/ _duration;
  }

  Future<void> _pickTime(String current, ValueChanged<String> onPicked) async {
    final parts = current.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => onPicked(formatTimeOfDay(picked.hour, picked.minute)));
    }
  }

  Future<void> _save() async {
    final error = _error;
    if (error != null) {
      showAppSnack(context, error, error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await ref
          .read(doctorRepositoryProvider)
          .createAvailability(
            Availability(
              days: _days.toList(),
              start: _start,
              end: _end,
              lunchEnabled: _lunch,
              lunchStart: _lunchStart,
              lunchEnd: _lunchEnd,
              slotDuration: _duration,
              location: _location,
            ),
          );
      ref.invalidate(availabilitiesProvider);
      ref.invalidate(doctorDashboardProvider);
      if (!mounted) return;
      showAppSnack(
        context,
        '${saved.slotsPerWeek} créneaux hebdomadaires enregistrés.',
      );
      context.pop();
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final refs = ref.watch(referentialsProvider);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const BackAppBar(title: 'Ajouter Une Disponibilité'),
      body: AsyncValueView<Referentials>(
        value: refs,
        onRetry: () => ref.invalidate(referentialsProvider),
        builder: _buildForm,
      ),
    );
  }

  Widget _buildForm(Referentials refs) {
    final error = _error;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            children: [
              const Row(
                children: [
                  StatusBadge(
                    label: 'HDS SANTÉ STANDARD',
                    icon: Icons.verified_user_outlined,
                    color: AppColors.success,
                    background: AppColors.successSoft,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Praticien référent',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Définissez vos plages horaires de consultation récurrentes ou ponctuelles.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              NumberedSection(
                number: 1,
                title: 'Choisir les jours',
                trailing: Text(
                  '${_days.length} sélectionné${_days.length > 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.6,
                children: [
                  for (final d in refs.weekDays)
                    SelectTile(
                      selected: _days.contains(d),
                      padding: EdgeInsets.zero,
                      onTap: () => setState(
                        () =>
                            _days.contains(d) ? _days.remove(d) : _days.add(d),
                      ),
                      child: Center(child: Text(d)),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              const NumberedSection(number: 2, title: 'Horaires de la plage'),
              Row(
                children: [
                  Expanded(
                    child: _TimeField(
                      label: 'Début',
                      icon: Icons.schedule,
                      value: _start,
                      onTap: () => _pickTime(_start, (v) => _start = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TimeField(
                      label: 'Fin',
                      icon: Icons.schedule,
                      value: _end,
                      onTap: () => _pickTime(_end, (v) => _end = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SectionCard(
                color: AppColors.surfaceSoft,
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.restaurant_outlined,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pause déjeuner',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              Text(
                                'Exclure un intervalle méridien',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _lunch,
                          onChanged: (v) => setState(() => _lunch = v),
                        ),
                      ],
                    ),
                    if (_lunch) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _TimeField(
                              label: 'Début pause',
                              value: _lunchStart,
                              onTap: () => _pickTime(
                                _lunchStart,
                                (v) => _lunchStart = v,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _TimeField(
                              label: 'Reprise',
                              value: _lunchEnd,
                              onTap: () =>
                                  _pickTime(_lunchEnd, (v) => _lunchEnd = v),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const NumberedSection(number: 3, title: 'Durée par consultation'),
              Row(
                children: [
                  for (final d in refs.slotDurations)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: SelectTile(
                          selected: d == _duration,
                          onTap: () => setState(() => _duration = d),
                          child: Center(
                            child: Text(d == 60 ? '1 heure' : '$d min'),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              const NumberedSection(number: 4, title: 'Lieu ou Type'),
              for (final l in refs.availabilityLocations)
                RadioOptionTile(
                  title: l.label,
                  subtitle: l.subtitle,
                  icon: iconFor(l.icon),
                  radioFirst: false,
                  selected: _location == l.id,
                  onTap: () => setState(() => _location = l.id),
                ),
              const SizedBox(height: 8),
              error == null
                  ? InfoBanner(
                      icon: Icons.auto_awesome_outlined,
                      title: 'Synthèse automatique',
                      color: AppColors.success,
                      background: AppColors.mintSoft,
                      text:
                          'Générera environ $_slotsPerDay créneaux réservables par jour (soit ~${_slotsPerDay * _days.length} créneaux / semaine).',
                    )
                  : InfoBanner(
                      icon: Icons.error_outline,
                      title: 'Plage invalide',
                      color: AppColors.danger,
                      background: AppColors.dangerSoft,
                      text: error,
                    ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: PrimaryButton(
              label: 'Enregistrer les disponibilités',
              icon: Icons.save_outlined,
              loading: _saving,
              onPressed: error == null ? _save : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.value,
    required this.onTap,
    this.icon,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AppColors.border),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Icon(
                    Icons.access_time,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
