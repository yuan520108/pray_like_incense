import 'package:flutter/material.dart';

class AppBottomNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const AppBottomNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final icons = [
      'assets/icons/home.png',
      'assets/icons/pray.png',
      'assets/icons/add.png',
      'assets/icons/friends.png',
      'assets/icons/Nova.png',
    ];

    return Container(
      height: 76,
      decoration: const BoxDecoration(
        color: Color(0xFF262E52),
        border: Border(top: BorderSide(color: Colors.white24, width: 1)),
      ),
      child: Row(
        children: List.generate(icons.length, (index) {
          final isSelected = selectedIndex == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelected(index),
              behavior: HitTestBehavior.opaque,
              child: Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? const Color(0xFFF9D464) : const Color(0xFFF4F5F7),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFFF9D464).withValues(alpha: 0.5),
                              blurRadius: 12,
                              spreadRadius: 2,
                            )
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Image.asset(
                      icons[index],
                      width: 28, // 統一放大圖示尺寸，確保視覺完全對齊
                      height: 28,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}