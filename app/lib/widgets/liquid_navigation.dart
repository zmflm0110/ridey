import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:ridey_app/design/ridey_theme.dart';

class LiquidNavigation extends StatelessWidget {
  const LiquidNavigation({
    super.key,
    required this.index,
    required this.items,
    required this.onChanged,
  });

  final int index;
  final List<RideyNavigationItem> items;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final background = theme.colorScheme.surface.withValues(alpha: .84);

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: background,
              border: Border.all(
                color: context.ridey.line.withValues(alpha: .8),
              ),
              borderRadius: BorderRadius.circular(30),
            ),
            child: SizedBox(
              height: 64,
              child: Row(
                children: List.generate(
                  items.length,
                  (itemIndex) => Expanded(
                    child: _LiquidNavigationItem(
                      item: items[itemIndex],
                      selected: index == itemIndex,
                      reducedMotion: reducedMotion,
                      onTap: () => onChanged(itemIndex),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LiquidNavigationItem extends StatelessWidget {
  const _LiquidNavigationItem({
    required this.item,
    required this.selected,
    required this.reducedMotion,
    required this.onTap,
  });

  final RideyNavigationItem item;
  final bool selected;
  final bool reducedMotion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedColor = theme.colorScheme.onSurface;
    final unselectedColor = context.ridey.muted;

    return Semantics(
      button: true,
      selected: selected,
      label: '${item.label} 탭',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: reducedMotion
              ? Duration.zero
              : const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
          decoration: BoxDecoration(
            color: selected
                ? theme.colorScheme.onSurface.withValues(alpha: .08)
                : null,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                item.icon,
                color: selected ? selectedColor : unselectedColor,
                size: 22,
              ),
              const SizedBox(height: 3),
              Text(
                item.label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: selected ? selectedColor : unselectedColor,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RideyNavigationItem {
  const RideyNavigationItem(this.label, this.icon);

  final String label;
  final IconData icon;
}
