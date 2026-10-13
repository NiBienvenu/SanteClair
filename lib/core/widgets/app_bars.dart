import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'common.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 30});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(Icons.health_and_safety_outlined, color: Colors.white, size: size * 0.6),
    );
  }
}

/// Barre d'en-tête des onglets principaux : logo, "SantéClair" + titre.
class BrandAppBar extends StatelessWidget implements PreferredSizeWidget {
  const BrandAppBar({
    super.key,
    required this.title,
    this.showHdsBadge = false,
    this.actions = const [],
  });

  final String title;
  final bool showHdsBadge;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      toolbarHeight: 60,
      titleSpacing: 16,
      title: Row(
        children: [
          const BrandLogo(),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SantéClair',
                style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w700),
              ),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
      actions: [
        if (showHdsBadge)
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: StatusBadge(
              label: 'HDS Certifié',
              color: AppColors.success,
              background: AppColors.successSoft,
              icon: Icons.verified_user_outlined,
            ),
          ),
        ...actions,
        const SizedBox(width: 8),
      ],
    );
  }
}

/// Barre des écrans secondaires : flèche retour, titre, avatar.
class BackAppBar extends StatelessWidget implements PreferredSizeWidget {
  const BackAppBar({super.key, required this.title, this.onClose, this.trailing});

  final String title;
  final VoidCallback? onClose;
  final Widget? trailing;

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      title: Text(title),
      actions: [
        if (onClose != null) IconButton(icon: const Icon(Icons.close), onPressed: onClose),
        trailing ??
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: CircleAvatar(
                radius: 15,
                backgroundColor: AppColors.primary,
                child: Icon(Icons.person, size: 18, color: Colors.white),
              ),
            ),
      ],
    );
  }
}
