import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/file_pick.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_bars.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/form_fields.dart';
import '../../data/providers.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/patient_repository.dart';
import 'widgets/auth_widgets.dart';

class RegisterDoctorScreen extends ConsumerStatefulWidget {
  const RegisterDoctorScreen({super.key});

  @override
  ConsumerState<RegisterDoctorScreen> createState() => _RegisterDoctorScreenState();
}

class _RegisterDoctorScreenState extends ConsumerState<RegisterDoctorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _license = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _fee = TextEditingController();
  final _password = TextEditingController();
  String _specialty = 'Médecine générale';
  UploadFile? _card;
  bool _attest = false;
  bool _submitted = false;
  bool _loading = false;

  bool get _licenseValid => RegExp(r'^\d{11}$').hasMatch(_license.text.trim());

  @override
  void initState() {
    super.initState();
    _license.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in [_fullName, _license, _phone, _email, _fee, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickCard() async {
    final file = await pickUploadFile(extensions: const ['pdf', 'jpg', 'jpeg', 'png']);
    if (file != null) setState(() => _card = file);
  }

  Future<void> _submit() async {
    setState(() => _submitted = true);
    final valid = _formKey.currentState!.validate();
    if (!valid || _card == null || !_attest) {
      showAppSnack(
        context,
        _card == null
            ? 'Ajoutez votre carte professionnelle ou attestation.'
            : !_attest
            ? 'Veuillez attester de l\'exactitude de vos informations.'
            : 'Veuillez corriger les champs en erreur.',
        error: true,
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final message = await ref.read(authRepositoryProvider).registerDoctor(
        DoctorSignUp(
          fullName: _fullName.text.trim(),
          specialty: _specialty,
          licenseNumber: _license.text.trim(),
          phone: _phone.text.trim(),
          email: _email.text.trim(),
          fee: int.parse(_fee.text.replaceAll(RegExp(r'\D'), '')),
          password: _password.text,
          cardFileName: _card!.name,
          cardFilePath: _card!.path,
          cardBytes: _card!.bytes,
        ),
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.mark_email_read_outlined, color: AppColors.success, size: 40),
          title: const Text('Inscription envoyée'),
          content: Text(message),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(100, 40)),
              onPressed: () => Navigator.pop(context),
              child: const Text('Compris'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final specialties = ref.watch(referentialsProvider).value?.specialties ??
        const ['Médecine générale', 'Cardiologie', 'Pédiatrie', 'Dentiste', 'Gynécologie'];
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const BackAppBar(title: 'Créer Un Compte Médecin'),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            const AuthHeader(
              badge: 'INSCRIPTION PRO',
              secondBadge: 'HDS GARANTI',
              title: 'Espace Praticien',
              subtitle: 'Rejoignez le réseau médical SantéClair',
            ),
            LabeledField(
              label: 'Prénom et Nom',
              hint: 'Dr. Marc Joubert',
              controller: _fullName,
              validator: (v) {
                if (Validators.required(v) != null) return 'Nom obligatoire';
                return v!.trim().split(RegExp(r'\s+')).length < 2 ? 'Prénom et nom requis' : null;
              },
            ),
            const FieldLabel('Spécialité'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in specialties)
                  ChoiceChip(
                    label: Text(s),
                    selected: _specialty == s,
                    showCheckmark: false,
                    selectedColor: AppColors.primary,
                    backgroundColor: AppColors.surfaceTint,
                    side: BorderSide.none,
                    labelStyle: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: _specialty == s ? Colors.white : AppColors.textPrimary,
                    ),
                    onSelected: (_) => setState(() => _specialty = s),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            LabeledField(
              label: 'Numéro d\'exercice (RPPS / Ordre)',
              hint: '10004482910',
              controller: _license,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)],
              validator: (v) => RegExp(r'^\d{11}$').hasMatch(v?.trim() ?? '')
                  ? null
                  : 'Le numéro RPPS comporte 11 chiffres',
              labelTrailing: _licenseValid
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_outlined, size: 14, color: AppColors.primary),
                        SizedBox(width: 3),
                        Text('Vérifié', style: TextStyle(fontSize: 12, color: AppColors.primary)),
                      ],
                    )
                  : null,
            ),
            LabeledField(
              label: 'Téléphone professionnel',
              hint: '01 42 68 00 00',
              controller: _phone,
              keyboardType: TextInputType.phone,
              validator: Validators.phone,
            ),
            LabeledField(
              label: 'E-mail professionnel',
              hint: 'dr.joubert@cabinet.fr',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              validator: Validators.email,
            ),
            LabeledField(
              label: 'Tarif consultation standard',
              hint: '15 000 FBU',
              controller: _fee,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: Validators.amount,
              suffixIcon: const Icon(Icons.payments_outlined),
            ),
            PasswordField(controller: _password, validator: Validators.password),
            const FieldLabel('Carte professionnelle ou attestation'),
            _CardUploader(
              file: _card,
              showError: _submitted && _card == null,
              onPick: _pickCard,
            ),
            const SizedBox(height: 14),
            ConsentCheckbox(
              value: _attest,
              showError: _submitted && !_attest,
              onChanged: (v) => setState(() => _attest = v),
              text: 'J\'atteste sur l\'honneur l\'exactitude de mes titres et autorisations d\'exercice médical.',
            ),
            const SizedBox(height: 18),
            PrimaryButton(
              label: 'Valider mon inscription',
              trailingIcon: Icons.arrow_forward,
              loading: _loading,
              onPressed: _submit,
            ),
            const AuthFooterLink(question: 'Déjà un compte praticien ?', action: 'Se connecter'),
          ],
        ),
      ),
    );
  }
}

class _CardUploader extends StatelessWidget {
  const _CardUploader({required this.file, required this.onPick, required this.showError});

  final UploadFile? file;
  final VoidCallback onPick;
  final bool showError;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: showError ? AppColors.danger : AppColors.border),
      ),
      child: Column(
        children: [
          Icon(
            file == null ? Icons.badge_outlined : Icons.check_circle,
            color: file == null ? AppColors.primary : AppColors.success,
            size: 30,
          ),
          const SizedBox(height: 8),
          Text(
            file?.name ?? 'Justificatif officiel requis',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const Text(
            'Formats acceptés : PDF, JPG (Max. 10 Mo)',
            style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onPick,
            icon: const Icon(Icons.upload_file, size: 18),
            label: Text(file == null ? 'Ajouter un fichier' : 'Changer'),
          ),
        ],
      ),
    );
  }
}
