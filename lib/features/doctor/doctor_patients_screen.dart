import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_bars.dart';
import '../../core/widgets/common.dart';
import '../../data/models/doctor_space.dart';
import '../../data/providers.dart';
import 'widgets/patient_file_sheet.dart';

class DoctorPatientsScreen extends ConsumerWidget {
  const DoctorPatientsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patients = ref.watch(doctorPatientsProvider);
    return Scaffold(
      appBar: const BrandAppBar(title: 'Dossiers patients'),
      body: AsyncValueView<List<PatientBrief>>(
        value: patients,
        onRetry: () => ref.invalidate(doctorPatientsProvider),
        builder: (list) => RefreshIndicator(
          onRefresh: () => ref.refresh(doctorPatientsProvider.future),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final p = list[i];
              final initials = p.name.split(' ').where((s) => s.isNotEmpty).map((s) => s[0]).take(2).join();
              return SectionCard(
                padding: EdgeInsets.zero,
                child: ListTile(
                  onTap: () => showPatientFile(context, p, time: p.lastVisitTime),
                  leading: InitialsAvatar(initials: initials.toUpperCase(), size: 40),
                  title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${p.age} ans • ${p.reason}'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(p.lastVisitTime ?? '',
                          style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
                      Icon(p.mode == 'video' ? Icons.videocam_outlined : Icons.local_hospital_outlined,
                          size: 16, color: AppColors.textSecondary),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
