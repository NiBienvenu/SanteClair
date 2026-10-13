import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.validator,
    this.keyboardType,
    this.suffixIcon,
    this.textInputAction = TextInputAction.next,
    this.inputFormatters,
    this.labelTrailing,
    this.readOnly = false,
    this.onTap,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;
  final TextInputAction textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? labelTrailing;
  final bool readOnly;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldLabel(label, trailing: labelTrailing),
          TextFormField(
            controller: controller,
            validator: validator,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            inputFormatters: inputFormatters,
            readOnly: readOnly,
            onTap: onTap,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            decoration: InputDecoration(hintText: hint, suffixIcon: suffixIcon),
          ),
        ],
      ),
    );
  }
}

class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    this.label = 'Mot de passe',
    this.validator,
    this.labelTrailing,
    this.helper,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final Widget? labelTrailing;
  final String? helper;
  final VoidCallback? onSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldLabel(widget.label, trailing: widget.labelTrailing),
          TextFormField(
            controller: widget.controller,
            validator: widget.validator,
            obscureText: _obscure,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            onFieldSubmitted: (_) => widget.onSubmitted?.call(),
            decoration: InputDecoration(
              hintText: '••••••••',
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          if (widget.helper != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                widget.helper!,
                style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }
}

class ConsentCheckbox extends StatelessWidget {
  const ConsentCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    required this.text,
    this.showError = false,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String text;
  final bool showError;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: showError ? Border.all(color: AppColors.danger) : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(value: value, onChanged: (v) => onChanged(v ?? false)),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5))),
          ],
        ),
      ),
    );
  }
}
