import 'package:flutter/material.dart';

class RescuerBottomBarWidget extends StatelessWidget {
  final int selectedIndex;
  final VoidCallback onHomePressed;
  final VoidCallback onAssignmentsPressed;
  final VoidCallback onProfilePressed;

  const RescuerBottomBarWidget({
    super.key,
    required this.selectedIndex,
    required this.onHomePressed,
    required this.onAssignmentsPressed,
    required this.onProfilePressed,
  });

  List<({IconData icon, String label, VoidCallback onPressed})> get _items => [
    (
      icon: Icons.map_outlined,
      label: 'Map',
      onPressed: onHomePressed,
    ), // Home/Map (Index 0)
    (
      icon: Icons.assignment_outlined,
      label: 'Assignments',
      onPressed: onAssignmentsPressed,
    ), // Assignments (Index 1)
    (
      icon: Icons.person_outline,
      label: 'Profile',
      onPressed: onProfilePressed,
    ), // Profile (Index 2)
  ];

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: EdgeInsets.only(bottom: 0, left: 0, right: 0),
        padding: const EdgeInsets.only(left: 10, right: 10, top: 8, bottom: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 15,
              spreadRadius: 2,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(_items.length, (index) {
            final item = _items[index];
            final bool isSelected = selectedIndex == index;
            return _buildNavItem(
              icon: item.icon,
              label: item.label,
              isSelected: isSelected,
              onPressed: item.onPressed,
            );
          }),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onPressed,
  }) {
    final Color iconColor = isSelected
        ? Colors.blue.shade700
        : Colors.grey.shade600;
    final Color backgroundColor = isSelected
        ? Colors.blue.shade50
        : Colors.transparent;

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: iconColor),

            // const SizedBox(height: 2),
            // Text(
            //   label,
            //   style: TextStyle(
            //     fontSize: 10,
            //     color: iconColor,
            //     fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            //   ),
            // ),
          ],
        ),
      ),
    );
  }
}
