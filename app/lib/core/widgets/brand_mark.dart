import 'package:flutter/material.dart';

import '../../app/theme.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({
    this.size = 72,
    super.key,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.14),
      decoration: BoxDecoration(
        color: AppColors.deepMaroon,
        borderRadius: BorderRadius.circular(size * 0.26),
      ),
      child: Image.asset(
        'assets/branding/potoos/logo/potoos-logo-reference.png',
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) {
          return const Icon(
            Icons.photo_camera_back_outlined,
            color: AppColors.softGold,
          );
        },
      ),
    );
  }
}
