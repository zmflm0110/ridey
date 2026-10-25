import 'package:flutter/material.dart';
import 'package:ridey_app/design/ridey_theme.dart';
import 'package:ridey_app/widgets/ridey_ui.dart';

/// Bottom tabs like the web `nav#tabs`: a full-width bar with a hairline on
/// top, and one signal dot that springs over to the tab you're on.
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
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: context.ridey.line)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: LayoutBuilder(
            builder: (context, box) {
              final slot = (box.maxWidth - 12) / items.length;
              return Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 4, 6, 0),
                    child: Row(
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
                  ),
                  AnimatedPositioned(
                    duration: RideyMotion.of(context, RideyMotion.slide),
                    curve: RideyMotion.spring,
                    top: 5,
                    left: 6 + slot * (index + .5) - 2.5,
                    child: IgnorePointer(
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: context.ridey.signal,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
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
        scale: .92,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<Color?>(
              tween: ColorTween(end: color),
              duration: duration,
              builder: (context, value, _) =>
                  Icon(selected ? item.selectedIcon : item.icon, size: 25, color: value),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: duration,
              style: theme.textTheme.labelSmall!.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
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
