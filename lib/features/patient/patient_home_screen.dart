import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/app_icons.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_bars.dart';
import '../../core/widgets/common.dart';
import '../../data/models/appointment.dart';
import '../../data/models/doctor.dart';
import '../../data/models/patient.dart';
import '../../data/providers.dart';
import '../../router/app_router.dart';

class PatientHomeScreen extends ConsumerWidget {
  const PatientHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(patientHomeProvider);
    return Scaffold(
      appBar: BrandAppBar(
        title: 'Accueil',
        showHdsBadge: true,
        actions: [
          IconButton(
            onPressed: () => context.go(Routes.patientProfile),
            icon: const CircleAvatar(
              radius: 15,
              backgroundColor: AppColors.primary,
              child: Icon(Icons.person, size: 18, color: Colors.white),
            ),
          ),
        ],
      ),
      body: AsyncValueView<PatientHome>(
        value: home,
        onRetry: () => ref.invalidate(patientHomeProvider),
        builder: (data) => RefreshIndicator(
          onRefresh: () => ref.refresh(patientHomeProvider.future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _Greeting(home: data),
              const SizedBox(height: 14),
              const _SearchBar(),
              const SizedBox(height: 16),
              if (data.nextAppointment != null)
                _NextAppointmentCard(appointment: data.nextAppointment!)
              else
                const InfoBanner(
                  icon: Icons.event_available_outlined,
                  text: 'Aucun rendez-vous à venir. Réservez une consultation en quelques secondes.',
                ),
              const SectionTitle('Consultation rapide'),
              Row(
                children: [
                  for (final q in data.quickConsultations)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _QuickTile(
                          label: q.label,
                          icon: iconFor(q.icon),
                          onTap: () => context.push(
                            q.id == 'video'
                                ? '${Routes.doctorSearch}?video=true'
                                : '${Routes.doctorSearch}?specialty=${q.id}',
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              SectionTitle(
                'Mes médecins récents',
                trailing: GestureDetector(
                  onTap: () => context.push(Routes.doctorSearch),
                  child: const Text(
                    'Voir tout',
                    style: TextStyle(color: AppColors.primary, fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              for (final d in data.recentDoctors) _RecentDoctorTile(doctor: d),
              const SizedBox(height: 12),
              PrimaryButton(
                label: 'Nouveau rendez-vous',
                icon: Icons.add_circle_outline,
                onPressed: () => context.push(Routes.doctorSearch),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.home});

  final PatientHome home;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      'Bonjour ${home.firstName}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.waving_hand, color: Color(0xFFF2B33D), size: 22),
                ],
              ),
              Text(home.subtitle, style: const TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        ),
        if (home.verified)
          const StatusBadge(
            label: 'Compte vérifié',
            icon: Icons.verified,
            color: AppColors.success,
            background: AppColors.successSoft,
          ),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    return TextField(
      textInputAction: TextInputAction.search,
      onSubmitted: (q) => context.push('${Routes.doctorSearch}?q=${Uri.encodeQueryComponent(q)}'),
      decoration: InputDecoration(
        hintText: 'Médecin, spécialité, ville...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: IconButton(
          icon: const Icon(Icons.tune),
          onPressed: () => context.push(Routes.doctorSearch),
        ),
      ),
    );
  }
}

String relativeDayLabel(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final diff = DateTime(date.year, date.month, date.day).difference(today).inDays;
  if (diff == 0) return 'Aujourd\'hui';
  if (diff == 1) return 'Demain';
  return formatDateShort(date);
}

class _NextAppointmentCard extends StatelessWidget {
  const _NextAppointmentCard({required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    return SectionCard(
      color: AppColors.surfaceTint,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'PROCHAIN RENDEZ-VOUS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              StatusBadge(
                label: relativeDayLabel(a.date),
                icon: Icons.circle,
                color: AppColors.textPrimary,
                background: Colors.white,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              InitialsAvatar(initials: a.doctor.initials, background: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.doctor.displayName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    Text(a.doctor.specialty, style: const TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
            child: Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(a.time.replaceAll(':', 'h'), style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 14),
                Icon(a.isVideo ? Icons.videocam_outlined : Icons.location_on_outlined,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(a.location, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(42)),
                  onPressed: () => _showDirections(context, a),
                  icon: Icon(a.isVideo ? Icons.videocam : Icons.navigation_outlined, size: 18),
                  label: Text(a.isVideo ? 'Rejoindre' : 'Itinéraire'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(42),
                    backgroundColor: Colors.white,
                  ),
                  onPressed: () => context.push(Routes.booking(a.doctor.id, reschedule: a.id)),
                  icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                  label: const Text('Modifier'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDirections(BuildContext context, Appointment a) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(a.isVideo ? 'Téléconsultation' : 'Itinéraire',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(a.isVideo ? Icons.videocam_outlined : Icons.location_on_outlined,
                  color: AppColors.primary),
              title: Text(a.isVideo ? 'Lien sécurisé' : a.doctor.cabinetName),
              subtitle: Text(a.isVideo
                  ? 'Le lien sera actif 10 minutes avant le rendez-vous.'
                  : a.doctor.address),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.phone_outlined, color: AppColors.primary),
              title: const Text('Contacter le cabinet'),
              subtitle: Text(a.doctor.phone),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.surfaceTint,
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentDoctorTile extends StatelessWidget {
  const _RecentDoctorTile({required this.doctor});

  final Doctor doctor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DoctorRow(
        doctor: doctor,
        action: FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 34),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          onPressed: () => context.push(Routes.booking(doctor.id)),
          child: const Text('Prendre RDV'),
        ),
      ),
    );
  }
}

class DoctorRow extends StatelessWidget {
  const DoctorRow({super.key, required this.doctor, required this.action, this.showFee = false});

  final Doctor doctor;
  final Widget action;
  final bool showFee;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          InitialsAvatar(initials: doctor.initials, verified: doctor.verified),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doctor.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(doctor.specialty, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                if (showFee)
                  Text(
                    '${formatMoney(doctor.fee, doctor.currency)} • ${doctor.address}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
          action,
        ],
      ),
    );
  }
}
