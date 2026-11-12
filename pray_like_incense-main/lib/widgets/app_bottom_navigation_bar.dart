import 'package:flutter/material.dart';

import '../core/app_theme.dart';

class AppBottomNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const AppBottomNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  static const _items = [
    (asset: 'assets/icons/Homeicon.png', label: 'Home'),
    (asset: 'assets/icons/pray.png', label: 'Prayer'),
    (asset: 'assets/icons/Addicon.png', label: 'Create'),
    (asset: 'assets/icons/Profileicon.png', label: 'Search friends'),
    (asset: 'assets/icons/Nova.png', label: 'Nova AI'),
  ];

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('home-bottom-navigation'),
    decoration: const BoxDecoration(color: appBackground),
    child: SafeArea(
      top: false,
      child: SizedBox(
        height: 100,
        child: Row(
          children: List.generate(_items.length, (index) {
            final item = _items[index];
            final selected = selectedIndex == index;
            return Expanded(
              child: IconButton(
                key: ValueKey('bottom-nav-$index'),
                tooltip: item.label,
                onPressed: () => onSelected(index),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.standard,
                icon: AnimatedContainer(
                  key: ValueKey('bottom-nav-circle-$index'),
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  width: selected ? 80 : 70,
                  height: selected ? 80 : 70,
                  decoration: BoxDecoration(
                    color: selected ? appSelected : cream,
                    shape: BoxShape.circle,
                    boxShadow: selected
                        ? const [
                            BoxShadow(
                              color: Color(0x80FFDA82),
                              blurRadius: 15,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: AnimatedContainer(
                      key: ValueKey('bottom-nav-icon-box-$index'),
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      width: selected ? 58 : 46,
                      height: selected ? 58 : 46,
                      child: Image.asset(
                        item.asset,
                        key: ValueKey('bottom-nav-icon-$index'),
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    ),
  );
}
