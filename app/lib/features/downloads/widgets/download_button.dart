import 'package:flutter/material.dart';

import '../../../core/widgets/app_button.dart';

class DownloadButton extends StatelessWidget {
  const DownloadButton({
    required this.isDownloading,
    required this.onPressed,
    super.key,
  });

  final bool isDownloading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return AppButton(
      label: isDownloading ? 'Downloading...' : 'Download File',
      icon: Icons.download_outlined,
      onPressed: isDownloading ? null : onPressed,
    );
  }
}
