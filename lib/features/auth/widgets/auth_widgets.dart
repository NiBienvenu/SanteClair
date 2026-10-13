import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class AuthHeader extends StatelessWidget {
  const AuthHeader({
    super.key,
    required this.badge,
    required this.title,
    required this.subtitle,
    this.secondBadge,
  });

  final String badge;
  final String? secondBadge;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Tag(badge, AppColors.primary, AppColors.surfaceTint),
              if (secondBadge != null) ...[
                const SizedBox(width: 6),
                _Tag(secondBadge!, AppColors.success, AppColors.successSoft),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.label, this.color, this.background);

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_user_outlined, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class AuthFooterLink extends StatelessWidget {
  const AuthFooterLink({super.key, required this.question, required this.action});

  final String question;
  final String action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Center(
        child: GestureDetector(
          onTap: () => Navigator.of(context).maybePop(),
          child: Text.rich(
            TextSpan(
              text: '$question ',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              children: [
                TextSpan(
                  text: action,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
