import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_bars.dart';
import '../../core/widgets/common.dart';
import '../../data/models/appointment.dart';
import '../../data/providers.dart';
import '../../router/app_router.dart';
import 'widgets/appointment_status_badge.dart';

class AppointmentsScreen extends ConsumerWidget {
  const AppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointments = ref.watch(appointmentsProvider);
    return Scaffold(
      appBar: const BrandAppBar(title: 'Rendez-vous'),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => context.push(Routes.doctorSearch),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau'),
      ),
      body: AsyncValueView<List<Appointment>>(
        value: appointments,
        onRetry: () => ref.invalidate(appointmentsProvider),
        builder: (list) => RefreshIndicator(
          onRefresh: () => ref.refresh(appointmentsProvider.future),
          child: list.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 120),
                    Center(child: Text('Aucun rendez-vous pour le moment.')),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _AppointmentCard(appointment: list[i]),
                ),
        ),
      ),
    );
  }
}

class _AppointmentCard extends ConsumerWidget {
  const _AppointmentCard({required this.appointment});

  final Appointment appointment;

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler le rendez-vous ?'),
        content: Text('${appointment.doctor.displayName} • ${formatDayLong(appointment.date)} à ${appointment.time}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Non')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Oui, annuler', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(patientRepositoryProvider).cancelAppointment(appointment.id);
      ref
        ..invalidate(appointmentsProvider)
        ..invalidate(patientHomeProvider);
      if (context.mounted) showAppSnack(context, 'Rendez-vous annulé.');
    } on ApiException catch (e) {
      if (context.mounted) showAppSnack(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = appointment;
    final active = a.status != AppointmentStatus.cancelled && a.status != AppointmentStatus.completed;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InitialsAvatar(initials: a.doctor.initials, size: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.doctor.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(a.reason, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              AppointmentStatusBadge(status: a.status),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.event_outlined, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text('${formatDayLong(a.date)} • ${a.time}', style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(a.isVideo ? Icons.videocam_outlined : Icons.location_on_outlined,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(child: Text(a.location, overflow: TextOverflow.ellipsis)),
              Text(formatMoney(a.amount, a.currency), style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          if (active) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (a.status == AppointmentStatus.pendingPayment)
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(38)),
                      onPressed: () => context.push(Routes.payment(a.id)),
                      child: const Text('Payer'),
                    ),
                  )
                else
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => context.push(Routes.booking(a.doctor.id, reschedule: a.id)),
                      child: const Text('Modifier'),
                    ),
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                    onPressed: () => _cancel(context, ref),
                    child: const Text('Annuler'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
