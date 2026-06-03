import 'package:flutter/material.dart';

import '../../app/theme.dart';

class AppDivider extends StatelessWidget {
  const AppDivider({this.indent = 0, this.thickness = 0.6, super.key});

  final double indent;
  final double thickness;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: thickness,
      margin: EdgeInsets.symmetric(horizontal: indent),
      color: AppColors.creamLine,
    );
  }
}
