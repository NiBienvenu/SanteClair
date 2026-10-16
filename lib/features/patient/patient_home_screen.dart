import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
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
import '../../data/models/referentials.dart';
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
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
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
                  if (data.quickConsultations.isNotEmpty) ...[
                    const SectionTitle('Consultation rapide'),
                    _QuickConsultations(options: data.quickConsultations),
                  ],
                  SectionTitle(
                    'Mes médecins récents',
                    trailing: GestureDetector(
                      onTap: () => context.push(Routes.doctorSearch),
                      child: const Text(
                        'Voir tout',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  if (data.recentDoctors.isEmpty)
                    const _NoRecentDoctors()
                  else
                    for (final d in data.recentDoctors)
                      _RecentDoctorTile(doctor: d),
                  const SizedBox(height: 20),
                  PrimaryButton(
                    label: 'Nouveau rendez-vous',
                    icon: Icons.add_circle_outline,
                    onPressed: () => context.push(Routes.doctorSearch),
                  ),
                ],
              ),
            ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                home.firstName.isEmpty
                    ? 'Bonjour'
                    : 'Bonjour ${home.firstName}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.waving_hand, color: Color(0xFFF2B33D), size: 24),
          ],
        ),
        if (home.subtitle.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            home.subtitle,
            style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
          ),
        ],
        if (home.verified)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: StatusBadge(
              label: 'Compte vérifié',
              icon: Icons.verified,
              color: AppColors.success,
              background: AppColors.successSoft,
            ),
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
      onSubmitted: (q) => context.push(
        '${Routes.doctorSearch}?q=${Uri.encodeQueryComponent(q)}',
      ),
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
  final diff = DateTime(
    date.year,
    date.month,
    date.day,
  ).difference(today).inDays;
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
              InitialsAvatar(
                initials: a.doctor.initials,
                background: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.doctor.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      a.doctor.specialty,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.access_time,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  a.time.replaceAll(':', 'h'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 14),
                Icon(
                  a.isVideo
                      ? Icons.videocam_outlined
                      : Icons.location_on_outlined,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    a.location,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(42),
                  ),
                  onPressed: () => _showDirections(context, a),
                  icon: Icon(
                    a.isVideo ? Icons.videocam : Icons.navigation_outlined,
                    size: 18,
                  ),
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
                  onPressed: () => context.push(
                    Routes.booking(a.doctor.id, reschedule: a.id),
                  ),
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
            Text(
              a.isVideo ? 'Téléconsultation' : 'Itinéraire',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                a.isVideo
                    ? Icons.videocam_outlined
                    : Icons.location_on_outlined,
                color: AppColors.primary,
              ),
              title: Text(a.isVideo ? 'Lien sécurisé' : a.doctor.cabinetName),
              subtitle: Text(
                a.isVideo
                    ? 'Le lien sera actif 10 minutes avant le rendez-vous.'
                    : a.doctor.address,
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.phone_outlined,
                color: AppColors.primary,
              ),
              title: const Text('Contacter le cabinet'),
              subtitle: Text(a.doctor.phone),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickConsultations extends StatelessWidget {
  const _QuickConsultations({required this.options});

  final List<OptionItem> options;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.labelLarge!.copyWith(
      fontSize: 12,
      height: 1.3,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
      color: AppColors.textPrimary,
    );
    final textScaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    const spacing = 8.0;
    final width = 112.0 * (textScaler.scale(12) / 12).clamp(1.0, 2.0);
    var labelHeight = textScaler.scale(12) * 1.3 * 2;
    for (final option in options) {
      final painter = TextPainter(
        text: TextSpan(text: option.label, style: textStyle),
        textDirection: direction,
        textScaler: textScaler,
        locale: Localizations.maybeLocaleOf(context),
      )..layout(maxWidth: width - 16);
      if (painter.height > labelHeight) labelHeight = painter.height;
      painter.dispose();
    }
    final height = (16 + 32 + 6 + labelHeight).ceilToDouble();
    final scrollBehavior = ScrollConfiguration.of(context);
    return ScrollConfiguration(
      behavior: scrollBehavior.copyWith(
        dragDevices: {...scrollBehavior.dragDevices, PointerDeviceKind.mouse},
      ),
      child: SingleChildScrollView(
        key: const ValueKey('quick-consultations-scroll'),
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (var index = 0; index < options.length; index++) ...[
              if (index > 0) const SizedBox(width: spacing),
              SizedBox(
                key: ValueKey('quick-consultation-${options[index].id}'),
                width: width,
                height: height,
                child: _QuickTile(
                  label: options[index].label,
                  icon: iconFor(options[index].icon),
                  textStyle: textStyle,
                  isVideo: options[index].id == 'video',
                  onTap: () => context.push(
                    Uri(
                      path: Routes.doctorSearch,
                      queryParameters: options[index].id == 'video'
                          ? {'video': 'true'}
                          : {'specialty': options[index].id},
                    ).toString(),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({
    required this.label,
    required this.icon,
    required this.textStyle,
    required this.onTap,
    this.isVideo = false,
  });

  final String label;
  final IconData icon;
  final TextStyle textStyle;
  final VoidCallback onTap;
  final bool isVideo;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    return Material(
      color: isVideo ? AppColors.surfaceTint : AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isVideo ? AppColors.primary : AppColors.surfaceTint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: isVideo ? Colors.white : AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: textStyle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoRecentDoctors extends StatelessWidget {
  const _NoRecentDoctors();

  @override
  Widget build(BuildContext context) {
    return const SectionCard(
      child: Row(
        children: [
          Icon(
            Icons.medical_services_outlined,
            size: 30,
            color: AppColors.primary,
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aucun médecin récent',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 4),
                Text(
                  'Vos praticiens apparaîtront ici après votre premier rendez-vous.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
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
            textStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          onPressed: () => context.push(Routes.booking(doctor.id)),
          child: const Text('Prendre RDV'),
        ),
      ),
    );
  }
}

class DoctorRow extends StatelessWidget {
  const DoctorRow({
    super.key,
    required this.doctor,
    required this.action,
    this.showFee = false,
  });

  final Doctor doctor;
  final Widget action;
  final bool showFee;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          children: [
            InitialsAvatar(
              initials: doctor.initials,
              verified: doctor.verified,
              size: 38,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Tooltip(
                    message: doctor.displayName,
                    child: Text(
                      doctor.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    doctor.specialty,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (showFee) ...[
                    const SizedBox(height: 3),
                    Tooltip(
                      message:
                          '${formatMoney(doctor.fee, doctor.currency)} • ${doctor.address}',
                      child: Text(
                        '${formatMoney(doctor.fee, doctor.currency)} • ${doctor.address}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: constraints.maxWidth * 0.36,
              ),
              child: action,
            ),
          ],
        ),
      ),
    );
  }
}
