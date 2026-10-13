import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_icons.dart';
import '../../core/utils/file_pick.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_bars.dart';
import '../../core/widgets/common.dart';
import '../../data/models/appointment.dart';
import '../../data/models/referentials.dart';
import '../../data/providers.dart';
import '../../data/repositories/patient_repository.dart';
import '../../router/app_router.dart';
import 'widgets/appointment_status_badge.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key, required this.appointmentId});

  final String appointmentId;

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  String? _methodId;
  UploadFile? _receipt;
  bool _sending = false;
  bool _cancelling = false;

  Future<void> _pickReceipt() async {
    final file = await pickUploadFile(extensions: const ['jpg', 'jpeg', 'png', 'pdf']);
    if (file != null) setState(() => _receipt = file);
  }

  Future<void> _confirm(String methodId) async {
    if (_receipt == null) {
      showAppSnack(context, 'Ajoutez la capture de votre reçu de paiement.', error: true);
      return;
    }
    setState(() => _sending = true);
    try {
      await ref.read(patientRepositoryProvider).submitPayment(
        appointmentId: widget.appointmentId,
        methodId: methodId,
        receipt: _receipt!,
      );
      ref
        ..invalidate(patientHomeProvider)
        ..invalidate(appointmentsProvider)
        ..invalidate(appointmentProvider(widget.appointmentId));
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: AppColors.success, size: 44),
          title: const Text('Reçu envoyé'),
          content: const Text(
            'Votre justificatif a été transmis. Votre médecin confirmera le rendez-vous dès vérification du paiement.',
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(120, 40)),
              onPressed: () => Navigator.pop(context),
              child: const Text('Retour à l\'accueil'),
            ),
          ],
        ),
      );
      if (mounted) context.go(Routes.patientHome);
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _changeDate() async {
    setState(() => _cancelling = true);
    try {
      await ref.read(patientRepositoryProvider).cancelAppointment(widget.appointmentId);
      ref.invalidate(appointmentsProvider);
      if (mounted) context.pop();
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appointment = ref.watch(appointmentProvider(widget.appointmentId));
    final methods = ref.watch(paymentMethodsProvider);
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const BackAppBar(title: 'Confirmation & Paiement'),
      body: AsyncValueView<Appointment>(
        value: appointment,
        onRetry: () => ref.invalidate(appointmentProvider(widget.appointmentId)),
        builder: (a) => AsyncValueView<List<PaymentMethod>>(
          value: methods,
          onRetry: () => ref.invalidate(paymentMethodsProvider),
          builder: (list) => _buildContent(a, list),
        ),
      ),
    );
  }

  Widget _buildContent(Appointment a, List<PaymentMethod> methods) {
    final payable = a.status == AppointmentStatus.pendingPayment;
    final methodId = _methodId ?? a.paymentMethod ?? methods.first.id;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        const Text('Votre rendez-vous', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const Text('Validation et transmission du justificatif',
            style: TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 14),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _IconBox(Icons.medical_services_outlined),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('MÉDECIN',
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                        Text(a.doctor.displayName, style: const TextStyle(fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  AppointmentStatusBadge(status: a.status),
                ],
              ),
              const Divider(height: 24),
              _InfoLine(
                icon: Icons.event_outlined,
                label: 'Date & Heure',
                value: '${formatDayLong(a.date)} à ${a.time}',
              ),
              const SizedBox(height: 10),
              _InfoLine(
                icon: a.isVideo ? Icons.videocam_outlined : Icons.location_on_outlined,
                label: 'Lieu',
                value: a.location,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.surfaceTint, borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('Montant à régler', style: TextStyle(color: AppColors.textSecondary)),
                    ),
                    Text(formatMoney(a.amount, a.currency),
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primary)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Mode de paiement', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              for (final m in methods)
                RadioOptionTile(
                  title: m.label,
                  subtitle: m.account,
                  icon: iconFor(m.icon),
                  selected: m.id == methodId,
                  onTap: payable ? () => setState(() => _methodId = m.id) : () {},
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Capture du reçu', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              _ReceiptBox(
                fileName: _receipt?.name ?? a.receiptName,
                editable: payable,
                onPick: _pickReceipt,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const InfoBanner(
          icon: Icons.verified_user_outlined,
          text: 'Votre médecin confirme le rendez-vous dès réception du reçu.',
        ),
        const SizedBox(height: 18),
        if (payable) ...[
          PrimaryButton(
            label: 'Confirmer et envoyer',
            trailingIcon: Icons.arrow_forward,
            loading: _sending,
            onPressed: _cancelling ? null : () => _confirm(methodId),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: _sending || _cancelling ? null : _changeDate,
            child: _cancelling
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Modifier la date',
                    style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          ),
        ] else
          PrimaryButton(
            label: 'Retour à l\'accueil',
            onPressed: () => context.go(Routes.patientHome),
          ),
      ],
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(color: AppColors.surfaceTint, borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, size: 20, color: AppColors.primary),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReceiptBox extends StatelessWidget {
  const _ReceiptBox({required this.fileName, required this.editable, required this.onPick});

  final String? fileName;
  final bool editable;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    if (fileName == null) {
      return OutlinedButton.icon(
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(64)),
        onPressed: onPick,
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('Ajouter la capture du reçu (JPG, PNG, PDF)'),
      );
    }
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.mintSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.successSoft),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt_long_outlined, color: AppColors.success),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fileName!, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const Text('Validé',
                    style: TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          if (editable)
            FilledButton.tonal(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 34)),
              onPressed: onPick,
              child: const Text('Changer'),
            ),
        ],
      ),
    );
  }
}
