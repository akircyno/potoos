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
  UploadFile? selectedFile;
  bool isPicking = false;

  @override
  Widget build(BuildContext context) {
    final routeAlbum = ModalRoute.of(context)?.settings.arguments;
    final album = routeAlbum is Album ? routeAlbum : null;
    final canUpload = album?.canUpload ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Upload')),
      body: AppScreen(
        children: [
          Text('Upload Original Photo',
              style: Theme.of(context).textTheme.headlineLarge),
          const SizedBox(height: 8),
          const Text(
            'Choose one photo and upload the original file. No compression, resizing, or conversion.',
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
            label: isPicking ? 'Opening picker...' : 'Choose Photo',
            icon: Icons.photo_library_outlined,
            secondary: true,
            onPressed: isPicking || !canUpload
                ? null
                : () => _pickFile(includeVideos: false),
          ),
          const SizedBox(height: 10),
          AppButton(
            label: 'Choose from Files',
            icon: Icons.folder_open_outlined,
            secondary: true,
            onPressed: isPicking || !canUpload
                ? null
                : () => _pickFile(includeVideos: false),
          ),
          const SizedBox(height: 20),
          if (selectedFile == null)
            const AppEmptyState(
              title: 'No file selected',
              message:
                  'Choose one original photo for this Sprint 1 upload test.',
            )
          else
            SelectedFileCard(file: selectedFile!),
          const SizedBox(height: 14),
          const Text(
            'Files will be uploaded in original quality.',
            style:
                TextStyle(color: AppColors.maroon, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 22),
          AppButton(
            label: 'Upload Original File',
            icon: Icons.cloud_upload_outlined,
            onPressed: selectedFile == null || !canUpload
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
                      arguments:
                          UploadProgressArgs(album: album, file: selectedFile!),
                    );
                  },
          ),
        ],
      ),
    );
  }

  Future<void> _pickFile({bool includeVideos = true}) async {
    setState(() => isPicking = true);

    try {
      final file = await ref.read(fileServiceProvider).pickOriginalMediaFile(
            includeVideos: includeVideos,
          );
      if (file != null && mounted) {
        setState(() => selectedFile = file);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppError.messageFor(error))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isPicking = false);
      }
    }
  }
}
