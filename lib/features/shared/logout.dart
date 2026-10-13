import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/providers.dart';

class LogoutButton extends ConsumerWidget {
  const LogoutButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.dangerSoft,
        foregroundColor: AppColors.danger,
        minimumSize: const Size.fromHeight(48),
      ),
      onPressed: () async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Se déconnecter ?'),
            content: const Text('Vous devrez vous reconnecter pour accéder à vos données de santé.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Se déconnecter', style: TextStyle(color: AppColors.danger)),
              ),
            ],
          ),
        );
        if (confirmed == true) await ref.read(authControllerProvider.notifier).logout();
      },
      icon: const Icon(Icons.logout),
      label: const Text('Se déconnecter'),
    );
  }
}
