import 'package:flutter/material.dart';

import '../../app/theme.dart';

class MemoryStatCard extends StatelessWidget {
  const MemoryStatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.gold = false,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    final color = gold ? AppColors.softGold : AppColors.maroon;

    return Expanded(
      child: Container(
        height: 82,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border.all(
              color: AppColors.maroon.withValues(alpha: 0.10), width: 0.6),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 18),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800)),
                Text(label,
                    style: const TextStyle(
                        color: AppColors.mutedInk, fontSize: 10.5)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
