import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/app_bars.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/form_fields.dart';
import '../../core/widgets/segmented_switch.dart';
import '../../data/models/app_user.dart';
import '../../data/providers.dart';
import '../../router/app_router.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  UserRole _role = UserRole.patient;
  bool _loading = false;
  bool _biometricLoading = false;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref
          .read(authControllerProvider.notifier)
          .login(_identifier.text.trim(), _password.text, _role);
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _biometric() async {
    setState(() => _biometricLoading = true);
    try {
      await ref.read(authControllerProvider.notifier).biometricLogin(_role);
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _biometricLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final controller = TextEditingController(text: _identifier.text);
    final identifier = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mot de passe oublié'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Saisissez votre e-mail ou téléphone pour recevoir un lien de réinitialisation.'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(hintText: 'nom@exemple.fr'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(80, 40)),
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (identifier == null || identifier.isEmpty || !mounted) return;
    try {
      final message = await ref.read(authRepositoryProvider).forgotPassword(identifier);
      if (mounted) showAppSnack(context, message);
    } on ApiException catch (e) {
      if (mounted) showAppSnack(context, e.message, error: true);
    }
  }

  void _fillDemo() {
    _identifier.text =
        _role == UserRole.doctor ? AppConfig.demoDoctorEmail : AppConfig.demoPatientEmail;
    _password.text = AppConfig.demoPassword;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: BrandLogo(size: 56)),
                    const SizedBox(height: 12),
                    const Text(
                      'SantéClair',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Bienvenue sur votre espace santé',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    SegmentedSwitch(
                      items: const [
                        SegmentItem('Patient', icon: Icons.person_outline),
                        SegmentItem('Médecin', icon: Icons.medical_services_outlined),
                      ],
                      selectedIndex: _role.index,
                      onChanged: (i) => setState(() => _role = UserRole.values[i]),
                    ),
                    const SizedBox(height: 12),
                    SegmentedSwitch(
                      items: const [SegmentItem('Connexion'), SegmentItem('Créer un compte')],
                      selectedIndex: 0,
                      onChanged: (i) {
                        if (i == 1) {
                          context.push(
                            _role == UserRole.doctor ? Routes.registerDoctor : Routes.registerPatient,
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    LabeledField(
                      label: 'E-mail ou Téléphone',
                      hint: 'nom@exemple.fr',
                      controller: _identifier,
                      keyboardType: TextInputType.emailAddress,
                      validator: Validators.emailOrPhone,
                    ),
                    PasswordField(
                      controller: _password,
                      validator: (v) => Validators.required(v, 'Mot de passe obligatoire'),
                      onSubmitted: _submit,
                      labelTrailing: GestureDetector(
                        onTap: _forgotPassword,
                        child: const Text(
                          'Mot de passe oublié ?',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    PrimaryButton(
                      label: 'Continuer',
                      trailingIcon: Icons.arrow_forward,
                      loading: _loading,
                      onPressed: _submit,
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text(
                        'ou',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                      onPressed: _biometricLoading ? null : _biometric,
                      icon: _biometricLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.fingerprint),
                      label: const Text('Empreinte / Face ID'),
                    ),
                    const SizedBox(height: 24),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.verified_user, size: 16, color: AppColors.success),
                        SizedBox(width: 6),
                        Text(
                          'Données de santé protégées HDS',
                          style: TextStyle(
                            color: AppColors.success,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (AppConfig.useMock) ...[
                      const SizedBox(height: 16),
                      InkWell(
                        onTap: _fillDemo,
                        child: InfoBanner(
                          icon: Icons.science_outlined,
                          title: 'Mode démo (données mock)',
                          text:
                              'Touchez ici pour pré-remplir : ${_role == UserRole.doctor ? AppConfig.demoDoctorEmail : AppConfig.demoPatientEmail} / ${AppConfig.demoPassword}',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
