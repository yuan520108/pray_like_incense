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
      'assets/icons/Homeicon.png',
      'assets/icons/Searchicon.png',
      'assets/icons/Addicon.png',
      'assets/icons/Profileicon.png',
      'assets/icons/Nova.png',
    ];

    return SafeArea(
      top: false,
      child: Container(
        height: 60,
        decoration: const BoxDecoration(
          color: Color(0xFF2D3656),
          border: Border(top: BorderSide(color: Colors.white24, width: 1)),
        ),
        child: Row(
          children: List.generate(icons.length, (index) {
            final isSelected = selectedIndex == index;
            final isAdd = index == 2;
            final size = isSelected
                ? (isAdd ? 55.0 : 48.0)
                : (isAdd ? 50.0 : 42.0);
            return Expanded(
              child: GestureDetector(
                onTap: () => onSelected(index),
                behavior: HitTestBehavior.opaque,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? const Color(0xFFFFDE97)
                          : isAdd
                          ? const Color(0xFFD9D9D9)
                          : Colors.white,
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(
                                  0xFFFFDE97,
                                ).withValues(alpha: 0.45),
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Image.asset(
                        icons[index],
                        width: isAdd ? 22 : 20,
                        height: isAdd ? 22 : 20,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
