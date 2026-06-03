import 'package:flutter/material.dart';

import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/poto_mascot.dart';

class AlbumEmptyState extends StatelessWidget {
  const AlbumEmptyState({
    required this.title,
    required this.message,
    this.expression = PotoExpression.waiting,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String title;
  final String message;
  final PotoExpression expression;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      title: title,
      message: message,
      expression: expression,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }
}
