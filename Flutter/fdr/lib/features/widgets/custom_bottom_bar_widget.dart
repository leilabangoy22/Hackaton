import 'package:flutter/material.dart';

class CustomBottomBarWidget extends StatelessWidget {
  final int selectedIndex;
  final VoidCallback onHomePressed;
  final VoidCallback onAddPressed;
  final VoidCallback onProfilePressed;

  const CustomBottomBarWidget({
    super.key,
    required this.selectedIndex,
    required this.onHomePressed,
    required this.onAddPressed,
    required this.onProfilePressed,
  });

  @override
  Widget build(BuildContext context) {
    final double bottomPadding = MediaQuery.of(context).padding.bottom;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: GestureDetector(

        onTap: () {},
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 80 + bottomPadding,
          color: Colors.transparent,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: 60 + bottomPadding,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        spreadRadius: 0,
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  padding: EdgeInsets.only(
                    bottom: bottomPadding,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildNavItem(
                        Icons.home_filled,
                        0, 
                        onHomePressed,
                        context,
                      ),
                      const SizedBox(width: 80),
                      _buildNavItem(
                        Icons.person_outline,
                        2, 
                        onProfilePressed,
                        context,
                      ),
                    ],
                  ),
                ),
              ),
         
              Positioned(
                top: 10,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.5),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 26,
                    ),
                    onPressed: onAddPressed,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    IconData icon,
    int index,
    VoidCallback onTap,
    BuildContext context,
  ) {
    final isSelected = selectedIndex == index;
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: index == 0 ? onTap : (isSelected ? null : onTap),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
        child: Icon(
          icon,
          color: isSelected ? theme.colorScheme.primary : Colors.grey[700],
          size: 28,
        ),
      ),
    );
  }
}