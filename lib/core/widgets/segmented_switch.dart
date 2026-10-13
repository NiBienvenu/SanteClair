import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class SegmentItem {
  const SegmentItem(this.label, {this.icon});

  final String label;
  final IconData? icon;
}

/// Sélecteur segmenté (Patient/Médecin, Connexion/Créer un compte, statut...).
class SegmentedSwitch extends StatelessWidget {
  const SegmentedSwitch({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onChanged,
    this.filledSelection = false,
  });

  final List<SegmentItem> items;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final bool filledSelection;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceTint,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: _Segment(
                item: items[i],
                selected: i == selectedIndex,
                filled: filledSelection,
                onTap: () => onChanged(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.item,
    required this.selected,
    required this.filled,
    required this.onTap,
  });

  final SegmentItem item;
  final bool selected;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = !selected
        ? Colors.transparent
        : filled
        ? AppColors.primary
        : Colors.white;
    final fg = selected
        ? (filled ? Colors.white : AppColors.primary)
        : AppColors.textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          boxShadow: selected && !filled
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4)]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (item.icon != null) ...[
              Icon(item.icon, size: 16, color: fg),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                item.label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
