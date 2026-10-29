import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:ridey_app/design/ridey_theme.dart';
import 'package:ridey_app/widgets/ridey_ui.dart';

/// Space list content needs so the last row can scroll clear of the floating tab.
const rideyTabClearance = 112.0;

/// Floating liquid-glass tab bar. The selected item sits on a brighter capsule,
/// and the bar blurs whatever scrolls behind it.
class RideyTabBar extends StatelessWidget {
  const RideyTabBar({
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
    final bottom = MediaQuery.paddingOf(context).bottom;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(36);

    return Padding(
      padding: EdgeInsets.fromLTRB(22, 0, 22, 8 + bottom),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? .45 : .14),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: dark
                      ? [
                          Colors.white.withValues(alpha: .18),
                          Colors.white.withValues(alpha: .07),
                        ]
                      : [
                          Colors.white.withValues(alpha: .78),
                          Colors.white.withValues(alpha: .46),
                        ],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: dark ? .24 : .85),
                ),
              ),
              child: SizedBox(
                height: 68,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final slot = constraints.maxWidth / items.length;
                    return Stack(
                      children: [
                        const Positioned(
                          left: 20,
                          right: 20,
                          top: 0,
                          child: _GlassHighlight(),
                        ),
                        AnimatedPositioned(
                          duration: RideyMotion.of(context, RideyMotion.slide),
                          curve: RideyMotion.ease,
                          left: slot * index + 6,
                          top: 6,
                          width: slot - 12,
                          height: constraints.maxHeight - 12,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              color: dark
                                  ? Colors.white.withValues(alpha: .16)
                                  : const Color(
                                      0xFFF2F2F4,
                                    ).withValues(alpha: .72),
                              border: Border.all(
                                color: Colors.white.withValues(
                                  alpha: dark ? .2 : .7,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            for (var i = 0; i < items.length; i++)
                              Expanded(
                                child: _Tab(
                                  item: items[i],
                                  selected: i == index,
                                  onTap: () => onChanged(i),
                                ),
                              ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassHighlight extends StatelessWidget {
  const _GlassHighlight();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        height: 1,
        color: Colors.white.withValues(
          alpha: Theme.of(context).brightness == Brightness.dark ? .35 : .95,
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.item, required this.selected, required this.onTap});

  final RideyNavigationItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected ? context.ridey.signal : context.ridey.muted;
    final duration = RideyMotion.of(context, const Duration(milliseconds: 250));

    return Semantics(
      selected: selected,
      label: '${item.label} 탭',
      excludeSemantics: true,
      button: true,
      child: RideyPressable(
        onTap: onTap,
        scale: .96,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<Color?>(
              tween: ColorTween(end: color),
              duration: duration,
              builder: (context, value, _) => Icon(
                selected ? item.selectedIcon : item.icon,
                size: 26,
                fill: selected ? 1 : 0,
                weight: selected ? 600 : 500,
                color: value,
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: duration,
              style: theme.textTheme.labelSmall!.copyWith(
                color: selected
                    ? theme.colorScheme.onSurface
                    : context.ridey.muted,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 11,
              ),
              child: Text(item.label),
            ),
          ],
        ),
      ),
    );
  }
}

class RideyNavigationItem {
  const RideyNavigationItem(this.label, this.icon, [IconData? selectedIcon])
    : selectedIcon = selectedIcon ?? icon;

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
