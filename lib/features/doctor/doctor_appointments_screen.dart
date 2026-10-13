import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_bars.dart';
import '../../core/widgets/common.dart';
import '../../data/models/doctor_space.dart';
import '../../data/providers.dart';
import '../../router/app_router.dart';

/// Plages de disponibilité enregistrées par le praticien.
class DoctorAppointmentsScreen extends ConsumerWidget {
  const DoctorAppointmentsScreen({super.key});

  static const _locationLabels = {
    'cabinet': 'Au cabinet',
    'video': 'Téléconsultation vidéo',
    'both': 'Cabinet & vidéo',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availabilities = ref.watch(availabilitiesProvider);
    return Scaffold(
      appBar: const BrandAppBar(title: 'Mes disponibilités'),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => context.push(Routes.addAvailability),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
      body: AsyncValueView<List<Availability>>(
        value: availabilities,
        onRetry: () => ref.invalidate(availabilitiesProvider),
        builder: (list) => RefreshIndicator(
          onRefresh: () => ref.refresh(availabilitiesProvider.future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              if (list.isEmpty)
                const InfoBanner(
                  icon: Icons.event_busy_outlined,
                  text: 'Aucune plage définie. Ajoutez vos disponibilités pour recevoir des réservations.',
                ),
              for (final a in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.event_repeat, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text('${a.start} - ${a.end}',
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                            ),
                            StatusBadge(
                              label: a.slotDuration == 60 ? '1 h' : '${a.slotDuration} min',
                              color: AppColors.primary,
                              background: AppColors.surfaceTint,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final d in a.days)
                              StatusBadge(label: d, color: AppColors.textPrimary, background: AppColors.surfaceSoft),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          [
                            _locationLabels[a.location] ?? a.location,
                            if (a.lunchEnabled) 'Pause ${a.lunchStart} - ${a.lunchEnd}',
                            '${a.slotsPerDay} créneaux/jour • ~${a.slotsPerWeek}/semaine',
                          ].join(' • '),
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
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
