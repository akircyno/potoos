import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_screen.dart';
import '../data/album_repository.dart';
import '../providers/album_provider.dart';

class CreateAlbumScreen extends ConsumerStatefulWidget {
  const CreateAlbumScreen({super.key});

  @override
  ConsumerState<CreateAlbumScreen> createState() => _CreateAlbumScreenState();
}

class _CreateAlbumScreenState extends ConsumerState<CreateAlbumScreen> {
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  bool isLoading = false;

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Album')),
      body: AppScreen(
        children: [
          Text(
            'Start a private space for original memories.',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'The creator becomes Admin. Invites can be added later from the album.',
            style: TextStyle(color: AppColors.mutedInk),
          ),
          const SizedBox(height: 22),
          TextField(
            controller: nameController,
            decoration: InputDecoration(
              labelText: 'Album name',
              prefixIcon: Icon(Icons.photo_album_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: descriptionController,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'Description',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 22),
          AppButton(
            label: isLoading ? 'Creating...' : 'Create Album',
            icon: Icons.add,
            onPressed: isLoading ? null : _createAlbum,
          ),
        ],
      ),
    );
  }

  Future<void> _createAlbum() async {
    final name = nameController.text.trim();
    final description = descriptionController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Album name cannot be empty.')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final album = await ref.read(albumRepositoryProvider).createAlbum(
            name: name,
            description: description.isEmpty ? null : description,
          );
      ref.invalidate(albumListProvider);

      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.albumDetails, arguments: album);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppError.messageFor(error))),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }
}
