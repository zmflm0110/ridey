import 'package:flutter/material.dart';
import 'package:ridey_app/design/ridey_theme.dart';
import 'package:ridey_app/widgets/ridey_ui.dart';

/// Space list content needs so the last row can scroll clear of the floating tab.
const rideyTabClearance = 112.0;

/// Floating tab bar in the brand rules: a surface pill with a 1px line and no
/// shadow. The selected tab is ink, and one signal dot springs along above it
/// (the web app's sliding dot). The bar blurs whatever scrolls behind it.
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
    final c = context.ridey;
    final radius = BorderRadius.circular(999);
    const dot = 6.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(22, 0, 22, 8 + bottom),
      child: ClipRRect(
        borderRadius: radius,
        // 흐림(BackdropFilter)은 지도(플랫폼 뷰) 위에서 프레임마다 화면을 다시 읽어 안드로이드에서 끊긴다 —
        // 거의 불투명한 면으로 대신한다(보기엔 같고, 움직임이 부드럽다).
        child: RepaintBoundary(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              color: Theme.of(
                context,
              ).colorScheme.surface.withValues(alpha: .97),
              border: Border.all(color: c.line),
            ),
            child: SizedBox(
              height: 68,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final slot = constraints.maxWidth / items.length;
                  return Stack(
                    children: [
                      AnimatedPositioned(
                        duration: RideyMotion.of(context, RideyMotion.slide),
                        curve: RideyMotion.spring,
                        left: slot * index + (slot - dot) / 2,
                        top: 7,
                        width: dot,
                        height: dot,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: c.signal,
                            shape: BoxShape.circle,
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
    final color = selected ? theme.colorScheme.onSurface : context.ridey.muted;
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
            const SizedBox(height: 6),
            TweenAnimationBuilder<Color?>(
              tween: ColorTween(end: color),
              duration: duration,
              builder: (context, value, _) => Icon(
                selected ? item.selectedIcon : item.icon,
                size: 24,
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
