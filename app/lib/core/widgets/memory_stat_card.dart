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
    final color = gold ? AppColors.brightGold : AppColors.velvetMaroon;

    return Expanded(
      child: Container(
        height: 88,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.warmCream,
          border: Border.all(
              color: gold
                  ? AppColors.brightGold.withValues(alpha: 0.28)
                  : AppColors.velvetMaroon.withValues(alpha: 0.10),
              width: 0.6),
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
