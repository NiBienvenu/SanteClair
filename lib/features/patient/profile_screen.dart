import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_icons.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_bars.dart';
import '../../core/widgets/common.dart';
import '../../data/models/patient.dart';
import '../../data/models/referentials.dart';
import '../../data/providers.dart';
import '../shared/logout.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _showSsn = false;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    return Scaffold(
      appBar: BrandAppBar(
        title: 'Profil',
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () => showAppSnack(context, 'Aucune nouvelle notification.'),
          ),
        ],
      ),
      body: AsyncValueView<PatientProfile>(
        value: profile,
        onRetry: () => ref.invalidate(profileProvider),
        builder: (p) => RefreshIndicator(
          onRefresh: () => ref.refresh(profileProvider.future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _Header(profile: p),
              const SizedBox(height: 16),
              _personalInfo(p),
              const SizedBox(height: 16),
              _menu(p),
              const SizedBox(height: 16),
              const LogoutButton(),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  '${AppConfig.appVersion} • Certifié HDS & RGPD Santé',
                  style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _personalInfo(PatientProfile p) {
    return SectionCard(
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Informations personnelles', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              TextButton.icon(
                onPressed: () => _edit(p),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Modifier'),
              ),
            ],
          ),
          _InfoTile(
            label: 'Date de naissance',
            value: p.birthDate == null ? 'Non renseignée' : formatBirthDate(p.birthDate!),
            trailing: const Icon(Icons.cake_outlined, color: AppColors.textSecondary),
          ),
          _InfoTile(
            label: 'Numéro de sécurité sociale',
            value: p.socialSecurityNumber == null
                ? 'Non renseigné'
                : _showSsn
                ? p.socialSecurityNumber!
                : maskSecret(p.socialSecurityNumber!),
            trailing: p.socialSecurityNumber == null
                ? null
                : IconButton(
                    icon: Icon(_showSsn ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                    onPressed: () => setState(() => _showSsn = !_showSsn),
                  ),
          ),
          _InfoTile(
            label: 'Contact d\'urgence',
            value: p.emergencyContact == null
                ? 'Non renseigné'
                : '${p.emergencyContact!.name} (${p.emergencyContact!.relation})\n${p.emergencyContact!.phone}',
            trailing: p.emergencyContact == null
                ? null
                : IconButton.filledTonal(
                    icon: const Icon(Icons.phone, size: 18),
                    onPressed: () => showAppSnack(context, 'Appel de ${p.emergencyContact!.phone}...'),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _menu(PatientProfile p) {
    final s = p.settings;
    return SectionCard(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          _MenuTile(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Moyens de paiement',
            subtitle: s.paymentMethodsSummary,
            onTap: _showPaymentMethods,
          ),
          _MenuTile(
            icon: Icons.notifications_active_outlined,
            title: 'Notifications & Rappels SMS',
            subtitle: s.notificationsSummary,
            badge: s.notificationsEnabled ? 'Actif' : null,
            onTap: () => _info('Notifications & Rappels SMS',
                'Vous recevez un rappel SMS 24h et 2h avant chaque consultation, ainsi qu\'une alerte à chaque renouvellement d\'ordonnance.'),
          ),
          _MenuTile(
            icon: Icons.lock_outline,
            title: 'Sécurité & Mot de passe',
            subtitle: s.securitySummary,
            onTap: () => _info('Sécurité & Mot de passe', s.securitySummary),
          ),
          _MenuTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Confidentialité & Partage médical',
            subtitle: s.sharingSummary,
            onTap: () => _info('Confidentialité & Partage médical',
                '${s.sharingSummary}. Vous pouvez révoquer un accès à tout moment.'),
          ),
          _MenuTile(
            icon: Icons.help_outline,
            title: 'Aide & Assistance',
            subtitle: s.helpSummary,
            onTap: () => _info('Aide & Assistance', 'support@santeclair.example • +257 22 00 00 00'),
          ),
        ],
      ),
    );
  }

  void _info(String title, String text) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Text(text),
          ],
        ),
      ),
    );
  }

  void _showPaymentMethods() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => Consumer(
        builder: (context, ref, _) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
          child: AsyncValueView<List<PaymentMethod>>(
            value: ref.watch(paymentMethodsProvider),
            onRetry: () => ref.invalidate(paymentMethodsProvider),
            builder: (methods) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Moyens de paiement', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                for (final m in methods)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(iconFor(m.icon), color: AppColors.primary),
                    title: Text(m.label),
                    subtitle: Text(m.account ?? 'Non configuré'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _edit(PatientProfile p) async {
    final changes = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _EditProfileSheet(profile: p),
    );
    if (changes == null || !mounted) return;
    try {
      await ref.read(patientRepositoryProvider).updateProfile(changes);
      ref.invalidate(profileProvider);
      if (mounted) showAppSnack(context, 'Informations mises à jour.');
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.profile});

  final PatientProfile profile;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    return SectionCard(
      child: Column(
        children: [
          InitialsAvatar(initials: p.initials, size: 72, verified: p.verified),
          const SizedBox(height: 10),
          Text(p.fullName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          if (p.verified)
            const StatusBadge(
              label: 'Compte vérifié',
              icon: Icons.verified,
              color: AppColors.success,
              background: AppColors.successSoft,
            ),
          const SizedBox(height: 6),
          Text('${p.email} • ${p.phone}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _MiniCard(icon: Icons.storage_outlined, title: 'Données Santé', value: p.dataHosting)),
              const SizedBox(width: 8),
              Expanded(child: _MiniCard(icon: Icons.shield_outlined, title: 'Consentement', value: p.consentStatus)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({required this.icon, required this.title, required this.value});

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppColors.surfaceSoft, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value, this.trailing});

  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: AppColors.surfaceSoft, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: AppColors.surfaceTint, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: AppColors.primary, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badge != null)
            StatusBadge(label: badge!, color: AppColors.success, background: AppColors.successSoft),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({required this.profile});

  final PatientProfile profile;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _phone = TextEditingController(text: widget.profile.phone);
  late final _email = TextEditingController(text: widget.profile.email);
  late final _contactName = TextEditingController(text: widget.profile.emergencyContact?.name);
  late final _contactRelation = TextEditingController(text: widget.profile.emergencyContact?.relation);
  late final _contactPhone = TextEditingController(text: widget.profile.emergencyContact?.phone);
  late DateTime? _birthDate = widget.profile.birthDate;

  @override
  void dispose() {
    for (final c in [_phone, _email, _contactName, _contactRelation, _contactPhone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(1990),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (date != null) setState(() => _birthDate = date);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, {
      'phone': _phone.text.trim(),
      'email': _email.text.trim(),
      'birthDate': _birthDate?.toIso8601String().substring(0, 10),
      'emergencyContact': EmergencyContact(
        name: _contactName.text.trim(),
        relation: _contactRelation.text.trim(),
        phone: _contactPhone.text.trim(),
      ).toJson(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Modifier mes informations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phone,
                decoration: const InputDecoration(labelText: 'Téléphone'),
                validator: Validators.phone,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _email,
                decoration: const InputDecoration(labelText: 'E-mail'),
                validator: Validators.email,
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                onPressed: _pickDate,
                icon: const Icon(Icons.cake_outlined),
                label: Text(_birthDate == null ? 'Date de naissance' : formatBirthDate(_birthDate!)),
              ),
              const SizedBox(height: 16),
              const Text('Contact d\'urgence', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _contactName,
                decoration: const InputDecoration(labelText: 'Nom'),
                validator: Validators.required,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _contactRelation,
                decoration: const InputDecoration(labelText: 'Lien (Frère, Mère...)'),
                validator: Validators.required,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _contactPhone,
                decoration: const InputDecoration(labelText: 'Téléphone'),
                validator: Validators.phone,
              ),
              const SizedBox(height: 18),
              PrimaryButton(label: 'Enregistrer', onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}
