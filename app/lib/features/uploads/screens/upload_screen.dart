import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/services/file_service.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_screen.dart';
import '../../albums/models/album.dart';
import '../models/upload_file.dart';
import '../widgets/selected_file_card.dart';

class UploadScreen extends ConsumerStatefulWidget {
  const UploadScreen({super.key});

  @override
  ConsumerState<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends ConsumerState<UploadScreen> {
  List<UploadFile> selectedFiles = [];
  bool isPicking = false;

  @override
  Widget build(BuildContext context) {
    final routeAlbum = ModalRoute.of(context)?.settings.arguments;
    final album = routeAlbum is Album ? routeAlbum : null;
    final canUpload = album?.canUpload ?? false;
    final count = selectedFiles.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Upload')),
      body: AppScreen(
        children: [
          Text('Upload Originals',
              style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 8),
          const Text(
            'Choose one or more photos and upload the original files. No compression, resizing, or conversion.',
            style: TextStyle(color: AppColors.mutedInk, height: 1.45),
          ),
          if (album != null) ...[
            const SizedBox(height: 8),
            Text(
              album.name,
              style: const TextStyle(
                  color: AppColors.softGold, fontWeight: FontWeight.w700),
            ),
            if (!album.canUpload) ...[
              const SizedBox(height: 12),
              const AppEmptyState(
                title: 'Viewer access',
                message:
                    'Viewers can open and download originals, but only Admins and Contributors can upload.',
              ),
            ],
          ] else ...[
            const SizedBox(height: 12),
            AppEmptyState(
              title: 'Choose an album first',
              message:
                  'Open Upload from an album so the file is stored in the right private space.',
              actionLabel: 'Back to Albums',
              onAction: () =>
                  Navigator.pushReplacementNamed(context, AppRoutes.home),
            ),
          ],
          const SizedBox(height: 22),
          AppButton(
            label: isPicking ? 'Opening picker...' : 'Choose Photos',
            icon: Icons.photo_library_outlined,
            secondary: true,
            onPressed: isPicking || !canUpload ? null : _pickFiles,
          ),
          const SizedBox(height: 10),
          AppButton(
            label: isPicking ? 'Opening picker...' : 'Choose Videos',
            icon: Icons.video_library_outlined,
            secondary: true,
            onPressed: isPicking || !canUpload
                ? null
                : () => _pickFiles(includeVideos: true),
          ),
          const SizedBox(height: 20),
          if (selectedFiles.isEmpty)
            const AppEmptyState(
              title: 'No files selected',
              message: 'Choose original photos or videos to upload.',
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    '$count file${count == 1 ? '' : 's'} selected',
                    style: const TextStyle(
                        color: AppColors.mutedInk,
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => selectedFiles = []),
                  child: const Text('Clear',
                      style: TextStyle(
                          color: AppColors.maroon, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final file in selectedFiles) ...[
              SelectedFileCard(file: file),
              const SizedBox(height: 8),
            ],
          ],
          const SizedBox(height: 14),
          const Text(
            'Files will be uploaded in original quality.',
            style: TextStyle(color: AppColors.maroon, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 22),
          AppButton(
            label: count > 1
                ? 'Upload $count Originals'
                : 'Upload Original File',
            icon: Icons.cloud_upload_outlined,
            onPressed: selectedFiles.isEmpty || !canUpload
                ? null
                : () {
                    if (album == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Open Upload from an album first.')),
                      );
                      return;
                    }
                    Navigator.pushNamed(
                      context,
                      AppRoutes.uploadProgress,
                      arguments: UploadProgressArgs(
                          album: album, files: selectedFiles),
                    );
                  },
          ),
        ],
      ),
    );
  }

  Future<void> _pickFiles({bool includeVideos = false}) async {
    setState(() => isPicking = true);
    try {
      final files = await ref
          .read(fileServiceProvider)
          .pickOriginalMediaFiles(includeVideos: includeVideos);
      if (files.isNotEmpty && mounted) {
        setState(() => selectedFiles = files);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppError.messageFor(error))),
        );
      }
    } finally {
      if (mounted) setState(() => isPicking = false);
    }
  }
}
