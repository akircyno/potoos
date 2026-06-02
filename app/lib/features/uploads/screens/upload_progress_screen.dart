import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_screen.dart';
import '../models/upload_file.dart';
import '../providers/upload_provider.dart';
import '../widgets/upload_progress_card.dart';

class UploadProgressScreen extends ConsumerStatefulWidget {
  const UploadProgressScreen({super.key});

  @override
  ConsumerState<UploadProgressScreen> createState() =>
      _UploadProgressScreenState();
}

class _UploadProgressScreenState extends ConsumerState<UploadProgressScreen> {
  UploadProgressArgs? args;
  bool started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    if (routeArgs is UploadProgressArgs) {
      args = routeArgs;
      if (!started) {
        started = true;
        Future.microtask(() {
          ref.read(uploadControllerProvider.notifier).upload(
                albumId: routeArgs.album.id,
                file: routeArgs.file,
              );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uploadArgs = args;
    final uploadState = ref.watch(uploadControllerProvider);
    final file = uploadArgs?.file;
    final album = uploadArgs?.album;

    if (file == null || album == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Upload')),
        body: const AppScreen(
          children: [
            AppEmptyState(
              title: 'Upload unavailable',
              message: 'Start uploads from an album with a selected file.',
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: AppScreen(
        padding: EdgeInsets.zero,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
            decoration: const BoxDecoration(
              color: AppColors.deepMaroon,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    InkWell(
                      onTap: uploadState.isUploading
                          ? null
                          : () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.white.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.close,
                            color: AppColors.white, size: 14),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('Cancel',
                        style: TextStyle(
                            color: AppColors.white.withValues(alpha: 0.70),
                            fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Uploading to',
                  style: Theme.of(context)
                      .textTheme
                      .headlineLarge
                      ?.copyWith(color: AppColors.warmCream),
                ),
                const SizedBox(height: 2),
                Text(
                  album.name,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(color: AppColors.goldLight),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '1 file selected',
                    style: const TextStyle(
                        color: AppColors.mutedInk, fontSize: 12),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.goldFaint,
                    border: Border.all(
                        color: AppColors.softGold.withValues(alpha: 0.30),
                        width: 0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.star, color: AppColors.softGold, size: 10),
                      SizedBox(width: 4),
                      Text('Original quality',
                          style: TextStyle(
                              color: AppColors.softGold,
                              fontSize: 10,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 60,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              children: [
                _SelectedThumb(isVideo: file.fileType == 'video'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: UploadProgressCard(
              name: file.name,
              size: file.sizeLabel,
              progress: uploadState.progress,
              status: uploadState.completedUpload != null
                  ? 'Done'
                  : uploadState.errorMessage != null
                      ? 'Failed'
                      : '${(uploadState.progress * 100).round()}%',
              done: uploadState.completedUpload != null,
              waiting: !uploadState.isUploading &&
                  uploadState.completedUpload == null &&
                  uploadState.errorMessage == null,
            ),
          ),
          if (uploadState.errorMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Text(
                uploadState.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.maroon,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
            ),
          if (uploadState.completedUpload != null)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Text(
                'Upload complete. The original file is now in the album.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.maroon,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.info_outline,
                    color: AppColors.maroon, size: 14),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    uploadState.isUploading
                        ? uploadState.progress < 0.16
                            ? 'Creating upload session...'
                            : uploadState.progress >= 0.90
                                ? 'Finalizing upload...'
                                : 'Uploading original bytes. Keep this screen open.'
                        : 'Files are uploaded in original quality. No compression.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.maroon,
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AppButton(
              label: uploadState.isUploading
                  ? 'Uploading...'
                  : uploadState.errorMessage == null
                      ? 'Back to Album'
                      : 'Try Again',
              icon: uploadState.errorMessage == null
                  ? Icons.check
                  : Icons.refresh,
              onPressed: uploadState.isUploading
                  ? null
                  : uploadState.errorMessage == null
                      ? () => Navigator.pushNamedAndRemoveUntil(
                            context,
                            AppRoutes.albumDetails,
                            ModalRoute.withName(AppRoutes.home),
                            arguments: album,
                          )
                      : () {
                          ref.read(uploadControllerProvider.notifier).upload(
                                albumId: album.id,
                                file: file,
                              );
                        },
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedThumb extends StatelessWidget {
  const _SelectedThumb({required this.isVideo});

  final bool isVideo;

  @override
  Widget build(BuildContext context) {
    const palettes = [
      [Color(0xFFD4A0AC), Color(0xFF8C2840)],
      [Color(0xFFD4C4A0), Color(0xFF8C7A30)],
      [Color(0xFFC4A0D4), Color(0xFF6B2C80)],
      [Color(0xFFB0D4D0), Color(0xFF2C7C78)],
    ];

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: palettes[isVideo ? 3 : 0]),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isVideo ? Icons.movie_outlined : Icons.image_outlined,
            color: AppColors.white,
            size: 20,
          ),
        ),
        Positioned(
          top: -4,
          right: -4,
          child: Container(
            width: 16,
            height: 16,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.maroon,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.warmCream, width: 1.5),
            ),
            child: const Icon(Icons.close, color: AppColors.white, size: 8),
          ),
        ),
      ],
    );
  }
}
