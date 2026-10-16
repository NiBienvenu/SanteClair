import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_bars.dart';
import '../../core/widgets/common.dart';
import '../../data/providers.dart';
import '../shared/logout.dart';

class DoctorProfileScreen extends ConsumerWidget {
  const DoctorProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final doctor = ref.watch(doctorDashboardProvider).value?.doctor;
    if (user == null) return const SizedBox.shrink();
    return Scaffold(
      appBar: const BrandAppBar(title: 'Profil'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            child: Column(
              children: [
                InitialsAvatar(
                  initials: user.initials,
                  size: 72,
                  verified: user.verified,
                ),
                const SizedBox(height: 10),
                Text(
                  user.displayName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  user.specialty ?? '',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 6),
                if (user.verified)
                  const StatusBadge(
                    label: 'Praticien vérifié',
                    icon: Icons.verified,
                    color: AppColors.success,
                    background: AppColors.successSoft,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SectionCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.email_outlined,
                    color: AppColors.primary,
                  ),
                  title: const Text('E-mail professionnel'),
                  subtitle: Text(user.email),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.phone_outlined,
                    color: AppColors.primary,
                  ),
                  title: const Text('Téléphone professionnel'),
                  subtitle: Text(user.phone),
                ),
                if (doctor != null) ...[
                  ListTile(
                    leading: const Icon(
                      Icons.location_on_outlined,
                      color: AppColors.primary,
                    ),
                    title: const Text('Cabinet'),
                    subtitle: Text(doctor.address),
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.payments_outlined,
                      color: AppColors.primary,
                    ),
                    title: const Text('Tarif consultation standard'),
                    subtitle: Text(formatMoney(doctor.fee, doctor.currency)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          const LogoutButton(),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              AppConfig.appVersion,
              style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
