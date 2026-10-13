import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../../data/models/appointment.dart';

class AppointmentStatusBadge extends StatelessWidget {
  const AppointmentStatusBadge({super.key, required this.status});

  final AppointmentStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, background) = switch (status) {
      AppointmentStatus.pendingPayment => (AppColors.danger, AppColors.dangerSoft),
      AppointmentStatus.paymentSubmitted => (AppColors.warning, AppColors.warningSoft),
      AppointmentStatus.confirmed => (AppColors.success, AppColors.successSoft),
      AppointmentStatus.completed => (AppColors.primary, AppColors.surfaceTint),
      AppointmentStatus.cancelled => (AppColors.textSecondary, AppColors.surfaceSoft),
    };
    return StatusBadge(label: status.label, color: color, background: background);
  }
}
