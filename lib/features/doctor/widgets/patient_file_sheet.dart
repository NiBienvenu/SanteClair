import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../../data/models/doctor_space.dart';

void showPatientFile(BuildContext context, PatientBrief patient, {String? time}) {
  final initials = patient.name.split(' ').where((s) => s.isNotEmpty).map((s) => s[0]).take(2).join();
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InitialsAvatar(initials: initials.toUpperCase(), size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(patient.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    Text('${patient.age} ans • ${patient.phone}',
                        style: const TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Line(icon: Icons.assignment_outlined, label: 'Motif', value: patient.reason),
          if (time != null) _Line(icon: Icons.access_time, label: 'Heure', value: time),
          _Line(icon: Icons.bloodtype_outlined, label: 'Groupe sanguin', value: patient.bloodGroup ?? '—'),
          _Line(
            icon: Icons.warning_amber_rounded,
            label: 'Allergies',
            value: patient.allergies.isEmpty ? 'Aucune connue' : patient.allergies.join(', '),
            danger: patient.allergies.isNotEmpty,
          ),
        ],
      ),
    ),
  );
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.label, required this.value, this.danger = false});

  final IconData icon;
  final String label;
  final String value;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: danger ? AppColors.danger : AppColors.primary),
          const SizedBox(width: 10),
          SizedBox(width: 120, child: Text(label, style: const TextStyle(color: AppColors.textSecondary))),
          Expanded(
            child: Text(value,
                style: TextStyle(fontWeight: FontWeight.w700, color: danger ? AppColors.danger : null)),
          ),
        ],
      ),
    );
  }
}
