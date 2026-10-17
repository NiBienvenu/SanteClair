import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/download_file.dart';
import '../../core/widgets/app_bars.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/segmented_switch.dart';
import '../../data/models/doctor_space.dart';
import '../../data/providers.dart';
import '../../data/repositories/doctor_repository.dart';
import '../../router/app_router.dart';
import 'widgets/patient_file_sheet.dart';

class DoctorDashboardScreen extends ConsumerStatefulWidget {
  const DoctorDashboardScreen({super.key});

  @override
  ConsumerState<DoctorDashboardScreen> createState() =>
      _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends ConsumerState<DoctorDashboardScreen> {
  final Set<String> _busy = {};
  DoctorAvailabilityStatus? _status;

  DoctorRepository get _repo => ref.read(doctorRepositoryProvider);

  Future<void> _run(
    String id,
    Future<void> Function() action, {
    String? success,
  }) async {
    setState(() => _busy.add(id));
    try {
      await action();
      ref.invalidate(doctorDashboardProvider);
      await ref.read(doctorDashboardProvider.future);
      if (mounted && success != null) showAppSnack(context, success);
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _changeStatus(
    DoctorAvailabilityStatus status,
    DoctorAvailabilityStatus previous,
  ) async {
    setState(() => _status = status);
    try {
      await _repo.updateStatus(status);
      if (mounted) showAppSnack(context, 'Statut : ${status.label}');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _status = previous);
      showAppSnack(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(doctorDashboardProvider);
    return Scaffold(
      appBar: const BrandAppBar(title: 'Rendez Vous', showHdsBadge: true),
      body: AsyncValueView<DoctorDashboard>(
        value: dashboard,
        onRetry: () => ref.invalidate(doctorDashboardProvider),
        builder: (d) {
          final status = _status ?? d.availabilityStatus;
          return RefreshIndicator(
            onRefresh: () => ref.refresh(doctorDashboardProvider.future),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _header(d, status),
                const SizedBox(height: 12),
                SegmentedSwitch(
                  filledSelection: true,
                  items: [
                    for (final s in DoctorAvailabilityStatus.values)
                      SegmentItem(s.label),
                  ],
                  selectedIndex: status.index,
                  onChanged: (i) {
                    final next = DoctorAvailabilityStatus.values[i];
                    if (next != status) _changeStatus(next, status);
                  },
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _StatCard(value: d.stats.today, label: 'RDV aujourd\'hui'),
                    const SizedBox(width: 8),
                    _StatCard(
                      value: d.stats.toConfirm,
                      label: 'à confirmer',
                      color: AppColors.danger,
                    ),
                    const SizedBox(width: 8),
                    _StatCard(
                      value: d.stats.teleconsultations,
                      label: 'Téléconsultation',
                    ),
                  ],
                ),
                SectionTitle(
                  'Planning du jour',
                  trailing: Text(
                    formatDayLong(d.date),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                for (final item in d.schedule) _scheduleTile(item),
                SectionTitle(
                  'Paiement à vérifier',
                  trailing: d.pendingPayments.isEmpty
                      ? null
                      : StatusBadge(
                          label:
                              '${d.pendingPayments.length} reçu${d.pendingPayments.length > 1 ? 's' : ''}',
                          color: AppColors.primary,
                          background: AppColors.surfaceTint,
                        ),
                ),
                if (d.pendingPayments.isEmpty)
                  const InfoBanner(
                    icon: Icons.task_alt,
                    text: 'Tous les paiements ont été vérifiés.',
                  )
                else
                  for (final p in d.pendingPayments) _paymentCard(p),
                const SizedBox(height: 18),
                PrimaryButton(
                  label: 'Ajouter une disponibilité',
                  icon: Icons.add_circle_outline,
                  onPressed: () => context.push(Routes.addAvailability),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _header(DoctorDashboard d, DoctorAvailabilityStatus status) {
    final (color, bg) = switch (status) {
      DoctorAvailabilityStatus.available => (
        AppColors.success,
        AppColors.successSoft,
      ),
      DoctorAvailabilityStatus.inConsultation => (
        AppColors.primary,
        AppColors.surfaceTint,
      ),
      DoctorAvailabilityStatus.onBreak => (
        AppColors.warning,
        AppColors.warningSoft,
      ),
    };
    return Row(
      children: [
        InitialsAvatar(
          initials: d.doctor.initials,
          size: 52,
          verified: d.doctor.verified,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                d.doctor.displayName,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                d.doctor.specialty,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        StatusBadge(
          label: status.label.toUpperCase(),
          icon: Icons.circle,
          color: color,
          background: bg,
        ),
      ],
    );
  }

  Widget _scheduleTile(ScheduleItem item) {
    final busy = _busy.contains(item.id);
    final small = FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(36),
      textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
    );

    if (item.isFreeSlot) {
      final blocked = item.status == 'blocked';
      return _TileShell(
        time: item.time,
        child: Row(
          children: [
            Expanded(
              child: Text(
                blocked ? 'Créneau bloqué' : 'Créneau libre',
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 34),
                backgroundColor: AppColors.surfaceTint,
              ),
              onPressed: busy
                  ? null
                  : () => _run(
                      item.id,
                      () => _repo.updateScheduleItem(
                        item.id,
                        blocked ? ScheduleAction.unblock : ScheduleAction.block,
                      ),
                    ),
              icon: Icon(
                blocked ? Icons.lock_open : Icons.lock_outline,
                size: 16,
              ),
              label: Text(blocked ? 'Débloquer' : 'Bloquer'),
            ),
          ],
        ),
      );
    }

    final patient = item.patient!;
    final (label, color, bg) = switch (item.status) {
      'pending' => ('En attente', AppColors.danger, AppColors.dangerSoft),
      'confirmed' => ('Confirmé', AppColors.success, AppColors.successSoft),
      'refused' => ('Refusé', AppColors.textSecondary, AppColors.surfaceSoft),
      _ => (item.status, AppColors.textSecondary, AppColors.surfaceSoft),
    };
    return _TileShell(
      time: item.time,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Row(
                      children: [
                        Icon(
                          item.mode == 'video'
                              ? Icons.videocam_outlined
                              : Icons.local_hospital_outlined,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          item.mode == 'video'
                              ? 'Téléconsultation'
                              : 'Au cabinet',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              StatusBadge(label: label, color: color, background: bg),
              if (item.status == 'confirmed') ...[
                const SizedBox(width: 6),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 34),
                    backgroundColor: AppColors.surfaceTint,
                  ),
                  onPressed: () =>
                      showPatientFile(context, patient, time: item.time),
                  icon: const Icon(Icons.folder_open_outlined, size: 16),
                  label: const Text('Dossier'),
                ),
              ],
            ],
          ),
          if (item.mode == 'video' && item.status == 'confirmed') ...[
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () =>
                  context.push(Routes.videoCall(item.id, doctor: true)),
              icon: const Icon(Icons.videocam),
              label: const Text('Rejoindre'),
            ),
          ],
          if (item.status == 'pending') ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: small.copyWith(
                      backgroundColor: const WidgetStatePropertyAll(
                        AppColors.success,
                      ),
                    ),
                    onPressed: busy
                        ? null
                        : () => _run(
                            item.id,
                            () => _repo.updateScheduleItem(
                              item.id,
                              ScheduleAction.accept,
                            ),
                            success: 'Rendez-vous de ${patient.name} accepté.',
                          ),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Accepter'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(36),
                      backgroundColor: AppColors.surfaceTint,
                      foregroundColor: AppColors.textPrimary,
                    ),
                    onPressed: busy ? null : () => _confirmRefuse(item),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Refuser'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmRefuse(ScheduleItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Refuser le rendez-vous ?'),
        content: Text(
          '${item.patient!.name} à ${item.time} sera notifié(e) du refus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Refuser',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _run(
        item.id,
        () => _repo.updateScheduleItem(item.id, ScheduleAction.refuse),
        success: 'Rendez-vous refusé.',
      );
    }
  }

  Widget _paymentCard(PendingPayment p) {
    final busy = _busy.contains(p.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SectionCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => _showReceipt(p),
              child: Container(
                width: 56,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.surfaceTint,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(
                  Icons.receipt_long,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.patientName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    formatMoney(p.amount, p.currency),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    'Via ${p.method} • ${p.time}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success,
                      minimumSize: const Size.fromHeight(36),
                      textStyle: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: busy
                        ? null
                        : () => _run(p.id, () async {
                            final message = await _repo.validatePayment(p.id);
                            if (mounted) showAppSnack(context, message);
                          }),
                    icon: busy
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.verified_outlined, size: 16),
                    label: const Text('Valider le paiement'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReceipt(PendingPayment p) {
    final imageReceipt = RegExp(
      r'\.(png|jpe?g)$',
      caseSensitive: false,
    ).hasMatch(p.receiptName ?? '');
    final image = imageReceipt && p.receiptUrl != null
        ? ref.read(apiClientProvider).getBytes(p.receiptUrl!)
        : null;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reçu de ${p.patientName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surfaceTint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: image == null
                  ? const Icon(
                      Icons.description_outlined,
                      size: 64,
                      color: AppColors.primary,
                    )
                  : FutureBuilder<Uint8List>(
                      future: image,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return const Center(
                            child: Text('Impossible de charger le reçu.'),
                          );
                        }
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        return Image.memory(
                          snapshot.data!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) =>
                              const Center(child: Text('Aperçu indisponible.')),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 10),
            Text(p.receiptName ?? 'reçu'),
            Text(
              '${formatMoney(p.amount, p.currency)} via ${p.method} à ${p.time}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          if (p.receiptUrl != null)
            TextButton.icon(
              onPressed: () => downloadApiFile(
                context,
                ref.read(apiClientProvider),
                url: p.receiptUrl!,
                fileName: p.receiptName ?? 'recu.pdf',
              ),
              icon: const Icon(Icons.download),
              label: const Text('Télécharger'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    this.color = AppColors.primary,
  });

  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SectionCard(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TileShell extends StatelessWidget {
  const _TileShell({required this.time, required this.child});

  final String time;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SectionCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 52,
              child: Text(
                time,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: AppColors.primary,
                ),
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
