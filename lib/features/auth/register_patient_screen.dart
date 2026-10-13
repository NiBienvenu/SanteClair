import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_bars.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/form_fields.dart';
import '../../data/providers.dart';
import '../../data/repositories/auth_repository.dart';
import 'widgets/auth_widgets.dart';

class RegisterPatientScreen extends ConsumerStatefulWidget {
  const RegisterPatientScreen({super.key});

  @override
  ConsumerState<RegisterPatientScreen> createState() => _RegisterPatientScreenState();
}

class _RegisterPatientScreenState extends ConsumerState<RegisterPatientScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _bloodGroup;
  bool _accept = false;
  bool _submitted = false;
  bool _loading = false;

  @override
  void dispose() {
    for (final c in [_firstName, _lastName, _phone, _email, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitted = true);
    final valid = _formKey.currentState!.validate();
    if (!valid || !_accept) {
      if (!_accept) showAppSnack(context, 'Veuillez accepter le traitement de vos données.', error: true);
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(authControllerProvider.notifier).registerPatient(
        PatientSignUp(
          firstName: _firstName.text.trim(),
          lastName: _lastName.text.trim(),
          phone: _phone.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
          bloodGroup: _bloodGroup,
          acceptTerms: _accept,
        ),
      );
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bloodGroups = ref.watch(referentialsProvider).value?.bloodGroups ??
        const ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: const BackAppBar(title: 'Créer Un Compte Patient'),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            const AuthHeader(
              badge: 'ESPACE SÉCURISÉ SANTÉ',
              title: 'Nouveau compte Patient',
              subtitle: 'Accédez à vos soins et rendez-vous',
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: LabeledField(
                    label: 'Prénom',
                    hint: 'Amina',
                    controller: _firstName,
                    validator: Validators.required,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: LabeledField(
                    label: 'Nom',
                    hint: 'Koné',
                    controller: _lastName,
                    validator: Validators.required,
                  ),
                ),
              ],
            ),
            LabeledField(
              label: 'Téléphone',
              hint: '07 00 12 34 56',
              controller: _phone,
              keyboardType: TextInputType.phone,
              validator: Validators.phone,
            ),
            LabeledField(
              label: 'E-mail',
              hint: 'amina@exemple.fr',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              validator: Validators.email,
            ),
            PasswordField(
              controller: _password,
              validator: Validators.password,
              helper: '8 caractères minimum, 1 chiffre et 1 symbole',
            ),
            const FieldLabel(
              'Groupe sanguin',
              trailing: Text('Optionnel', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.8,
              children: [
                for (final g in bloodGroups)
                  SelectTile(
                    selected: _bloodGroup == g,
                    padding: EdgeInsets.zero,
                    onTap: () => setState(() => _bloodGroup = _bloodGroup == g ? null : g),
                    child: Center(child: Text(g)),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            ConsentCheckbox(
              value: _accept,
              showError: _submitted && !_accept,
              onChanged: (v) => setState(() => _accept = v),
              text:
                  'J\'accepte le traitement sécurisé de mes données de santé conformément à la réglementation HDS et au RGPD médical.',
            ),
            const SizedBox(height: 18),
            PrimaryButton(
              label: 'Créer mon compte',
              icon: Icons.person_add_alt_1,
              loading: _loading,
              onPressed: _submit,
            ),
            const AuthFooterLink(question: 'Déjà inscrit ?', action: 'Se connecter'),
          ],
        ),
      ),
    );
  }
}
