import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/file_pick.dart';
import '../../core/utils/download_file.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_bars.dart';
import '../../core/widgets/common.dart';
import '../../data/models/patient.dart';
import '../../data/providers.dart';

class MedicalRecordScreen extends ConsumerStatefulWidget {
  const MedicalRecordScreen({super.key});

  @override
  ConsumerState<MedicalRecordScreen> createState() =>
      _MedicalRecordScreenState();
}

class _MedicalRecordScreenState extends ConsumerState<MedicalRecordScreen> {
  bool _uploading = false;
  bool _showAllRecords = false;

  Future<void> _upload(MedicalRecord record) async {
    final file = await pickUploadFile(
      extensions: record.acceptedFormats.map((f) => f.toLowerCase()).toList(),
    );
    if (file == null) return;
    setState(() => _uploading = true);
    try {
      await ref.read(patientRepositoryProvider).uploadDocument(file);
      ref.invalidate(medicalRecordProvider);
      if (mounted) {
        showAppSnack(context, '${file.name} ajouté à votre dossier.');
      }
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _download(MedicalDocument doc) async {
    if (doc.fileUrl == null) {
      showAppSnack(context, 'Aucun fichier joint à ce document.');
      return;
    }
    await downloadApiFile(
      context,
      ref.read(apiClientProvider),
      url: doc.fileUrl!,
      fileName: doc.fileName ?? doc.title,
    );
  }

  void _openConsultation(ConsultationHistory item) {
    String describe(dynamic value) {
      if (value is List) return value.map(describe).join(', ');
      if (value is Map) {
        return value.entries
            .map((entry) => '${entry.key}: ${describe(entry.value)}')
            .join('\n');
      }
      return value?.toString() ?? '';
    }

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            Text('${item.doctor} • ${formatDateFull(item.date)}'),
            const SizedBox(height: 16),
            const Text(
              'Notes de consultation',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(item.notes.isEmpty ? 'Aucune note renseignée.' : item.notes),
            if (item.prescription.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Prescription',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(describe(item.prescription)),
            ],
          ],
        ),
      ),
    );
  }

  void _open(MedicalDocument doc) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              doc.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            Text(
              formatDateFull(doc.date),
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            SectionCard(color: AppColors.surfaceSoft, child: Text(doc.details)),
            if (doc.fileName != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.picture_as_pdf_outlined,
                    color: AppColors.danger,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(doc.fileName!)),
                  if (doc.fileUrl != null)
                    IconButton(
                      onPressed: () => _download(doc),
                      icon: const Icon(Icons.download),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final record = ref.watch(medicalRecordProvider);
    return Scaffold(
      appBar: BrandAppBar(
        title: 'Dossier Médical',
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () =>
                showAppSnack(context, 'Aucune nouvelle notification.'),
          ),
        ],
      ),
      body: AsyncValueView<MedicalRecord>(
        value: record,
        onRetry: () => ref.invalidate(medicalRecordProvider),
        builder: (r) => RefreshIndicator(
          onRefresh: () => ref.refresh(medicalRecordProvider.future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Mon dossier de santé',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Mis à jour le ${formatDateShort(r.updatedAt)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (r.dataHosting.isNotEmpty)
                    StatusBadge(
                      label: r.dataHosting,
                      icon: Icons.verified_user_outlined,
                      color: AppColors.success,
                      background: AppColors.successSoft,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _StatCard(label: 'Groupe', value: r.bloodGroup ?? '—'),
                  const SizedBox(width: 8),
                  _StatCard(
                    label: 'Allergie',
                    value: r.allergies.isEmpty
                        ? 'Aucune'
                        : r.allergies.join(', '),
                    color: r.allergies.isEmpty
                        ? AppColors.primary
                        : AppColors.danger,
                  ),
                  const SizedBox(width: 8),
                  _StatCard(
                    label: 'Traitement',
                    value: '${r.activeTreatments} en cours',
                  ),
                ],
              ),
              SectionTitle(
                'Dernières ordonnances & bilans',
                trailing: r.records.length > 2
                    ? GestureDetector(
                        onTap: () =>
                            setState(() => _showAllRecords = !_showAllRecords),
                        child: Text(
                          _showAllRecords ? 'Réduire' : 'Tout voir',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12.5,
                          ),
                        ),
                      )
                    : null,
              ),
              if (r.records.isEmpty)
                const Text(
                  'Aucune ordonnance ni bilan.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              for (final doc in _showAllRecords ? r.records : r.records.take(2))
                _RecordCard(
                  doc: doc,
                  onOpen: () => _open(doc),
                  onDownload: doc.fileUrl == null ? null : () => _download(doc),
                ),
              SectionTitle(
                'Historique des consultations',
                trailing: r.consultations.isEmpty
                    ? null
                    : Text(
                        '${r.consultations.first.date.year}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
              ),
              if (r.consultations.isEmpty)
                const Text(
                  'Aucune consultation.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              for (final c in r.consultations)
                _HistoryTile(item: c, onTap: () => _openConsultation(c)),
              const SectionTitle('Documents & Radios'),
              for (final doc in r.documents)
                _RecordCard(
                  doc: doc,
                  onOpen: () => _open(doc),
                  onDownload: doc.fileUrl == null ? null : () => _download(doc),
                ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: AppColors.surfaceTint,
                  side: const BorderSide(color: AppColors.primary, width: 0.6),
                ),
                onPressed: _uploading ? null : () => _upload(r),
                icon: _uploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_circle_outline),
                label: const Text('Ajouter un document'),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Formats acceptés : ${r.acceptedFormats.join(', ')}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Text(
                    'Max ${r.maxSizeMb} Mo',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const InfoBanner(
                icon: Icons.lock_outline,
                text: 'Données chiffrées accessibles uniquement par vos praticiens autorisés conformément au secret médical et à la norme RGPD Santé.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    this.color = AppColors.primary,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SectionCard(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({
    required this.doc,
    required this.onOpen,
    required this.onDownload,
  });

  final MedicalDocument doc;
  final VoidCallback onOpen;
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) {
    final isLab = doc.type == 'lab';
    final icon = switch (doc.type) {
      'prescription' => Icons.receipt_long_outlined,
      'lab' => Icons.biotech_outlined,
      _ => Icons.description_outlined,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SectionCard(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isLab ? AppColors.mintSoft : AppColors.surfaceTint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: isLab ? AppColors.success : AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doc.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                      Text(
                        formatDateFull(doc.date),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isLab && onDownload != null)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 32),
                    ),
                    onPressed: onDownload,
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text(
                      'Télécharger',
                      style: TextStyle(fontSize: 12),
                    ),
                  )
                else
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 32),
                    ),
                    onPressed: onOpen,
                    child: const Text('Voir', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
            if (!isLab && doc.details.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(doc.details, style: const TextStyle(fontSize: 12)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.item, required this.onTap});

  final ConsultationHistory item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 5),
              child: Icon(Icons.circle, size: 8, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '${item.doctor} • ${item.place}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatDateShort(item.date),
                  style: const TextStyle(fontSize: 11.5),
                ),
                Text(
                  item.status,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
