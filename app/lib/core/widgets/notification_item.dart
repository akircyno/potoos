import 'package:flutter/material.dart';

import '../../app/theme.dart';

class NotificationItem extends StatelessWidget {
  const NotificationItem({
    required this.title,
    required this.message,
    required this.time,
    this.unread = false,
    super.key,
  });

  final String title;
  final String message;
  final String time;
  final bool unread;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(
          color: unread
              ? AppColors.brightGold.withValues(alpha: 0.40)
              : AppColors.creamLine,
          width: 0.8,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            unread ? Icons.notifications_active_outlined : Icons.notifications_none,
            color: unread ? AppColors.brightGold : AppColors.mutedInk,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(message, style: const TextStyle(color: AppColors.mutedInk)),
                const SizedBox(height: 6),
                Text(time, style: const TextStyle(color: AppColors.mutedInk, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
