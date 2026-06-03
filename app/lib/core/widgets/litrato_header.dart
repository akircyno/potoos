import 'package:flutter/material.dart';

import '../../app/theme.dart';

class LitratoHeader extends StatelessWidget {
  const LitratoHeader({
    this.title = 'Potoos',
    this.subtitle = 'Good morning, Maria',
    this.showAvatar = true,
    super.key,
  });

  final String title;
  final String subtitle;
  final bool showAvatar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      decoration: const BoxDecoration(
        color: AppColors.deepMaroon,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeaderTitle(title: title),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.warmCream.withValues(alpha: 0.60),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (showAvatar)
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppColors.softGold, AppColors.garnetHighlight],
                ),
                border: Border.all(
                    color: AppColors.goldLight.withValues(alpha: 0.50),
                    width: 1.5),
              ),
              child: const Text(
                'MA',
                style: TextStyle(
                    color: AppColors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeaderTitle extends StatelessWidget {
  const _HeaderTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    if (title != 'Potoos') {
      return Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.warmCream,
              fontSize: 18,
            ),
      );
    }

    return RichText(
      text: TextSpan(
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.warmCream,
              fontSize: 18,
            ),
        children: const [
          TextSpan(text: 'Poto'),
          TextSpan(text: 'os', style: TextStyle(color: AppColors.brightGold)),
        ],
      ),
    );
  }
}
