import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../data/album_repository.dart';
import '../providers/album_provider.dart';

class CreateAlbumScreen extends ConsumerStatefulWidget {
  const CreateAlbumScreen({super.key});

  @override
  ConsumerState<CreateAlbumScreen> createState() => _CreateAlbumScreenState();
}

class _CreateAlbumScreenState extends ConsumerState<CreateAlbumScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _nameFocus = FocusNode();
  bool _isLoading = false;
  String _previewName = '';

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() {
      setState(() => _previewName = _nameController.text);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nameFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final hasName = _previewName.trim().isNotEmpty;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.warmCream,
        body: Column(
          children: [
            // ── Header ───────────────────────────────────────────────────
            _Header(onClose: () => Navigator.pop(context)),

            // ── Scrollable content ────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.xl,
                  AppSpacing.md,
                  80 + bottomPad,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Album card preview
                    Center(child: _AlbumPreview(name: _previewName)),

                    const SizedBox(height: AppSpacing.xl),

                    // Name input
                    const Text(
                      'Name it.',
                      style: TextStyle(
                        fontFamily: AppTheme.headingFont,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.deepMaroon,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: _nameController,
                      focusNode: _nameFocus,
                      enabled: !_isLoading,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                        color: AppColors.charcoalInk,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'e.g. Bali Trip 2025',
                        hintStyle: TextStyle(
                          color: AppColors.featherTaupe,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      onSubmitted: (_) => _createAlbum(),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // Description input (optional)
                    const Text(
                      'Describe it.',
                      style: TextStyle(
                        fontFamily: AppTheme.headingFont,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.deepMaroon,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Optional — only you and your members see this.',
                      style: TextStyle(
                        color: AppColors.featherTaupe,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: _descController,
                      enabled: !_isLoading,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.charcoalInk,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'What is this space for?',
                        hintStyle: TextStyle(
                          color: AppColors.featherTaupe,
                          fontWeight: FontWeight.w400,
                        ),
                        alignLabelWithHint: true,
                      ),
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // Admin note
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.brightGold.withValues(alpha: 0.08),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd),
                        border: Border.all(
                          color: AppColors.brightGold.withValues(alpha: 0.22),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.admin_panel_settings_outlined,
                              color: AppColors.brightGold, size: 16),
                          SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'You become Admin. Invite people after creating.',
                              style: TextStyle(
                                color: AppColors.charcoalInk,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Sticky CTA ────────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                border: const Border(
                    top: BorderSide(color: AppColors.creamLine, width: 0.8)),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.midnightBurgundy.withValues(alpha: 0.06),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm,
                  AppSpacing.md, AppSpacing.sm + bottomPad),
              child: PressableScale(
                onTap: (_isLoading || !hasName) ? null : _createAlbum,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                child: Container(
                  height: 54,
                  width: double.infinity,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: (_isLoading || !hasName)
                        ? AppColors.creamLine
                        : AppColors.velvetMaroon,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusLg),
                    boxShadow: (!_isLoading && hasName)
                        ? AppShadows.primaryButton
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isLoading
                            ? Icons.hourglass_top_rounded
                            : Icons.add_circle_outline,
                        color: (_isLoading || !hasName)
                            ? AppColors.featherTaupe
                            : AppColors.pearlCream,
                        size: 18,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        _isLoading ? 'Creating...' : 'Create Space',
                        style: TextStyle(
                          color: (_isLoading || !hasName)
                              ? AppColors.featherTaupe
                              : AppColors.pearlCream,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createAlbum() async {
    final name = _nameController.text.trim();
    final description = _descController.text.trim();

    if (name.isEmpty) return;

    _nameFocus.unfocus();
    setState(() => _isLoading = true);

    try {
      final album = await ref.read(albumRepositoryProvider).createAlbum(
            name: name,
            description: description.isEmpty ? null : description,
          );
      ref.invalidate(albumListProvider);

      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.albumDetails,
          arguments: album,
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppError.messageFor(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      decoration: const BoxDecoration(
        gradient: AppGradients.header,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(16, top + 12, 16, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PressableScale(
            onTap: onClose,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.close, color: AppColors.white, size: 17),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create a space.',
                  style: TextStyle(
                    fontFamily: AppTheme.headingFont,
                    color: AppColors.pearlCream,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Private from the start. Only who you invite can enter.',
                  style: TextStyle(
                    color: AppColors.featherTaupe,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Live album preview ────────────────────────────────────────────────────────

class _AlbumPreview extends StatelessWidget {
  const _AlbumPreview({required this.name});

  final String name;

  // Use a fixed preview palette so it doesn't jump around
  static const _previewGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6B1C2E), Color(0xFFC4973A)],
  );

  @override
  Widget build(BuildContext context) {
    final displayName = name.trim().isEmpty ? 'Your space' : name.trim();
    final isDimmed = name.trim().isEmpty;

    return Opacity(
      opacity: isDimmed ? 0.45 : 1.0,
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          boxShadow: AppShadows.float,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover
            Container(
              height: 100,
              decoration: const BoxDecoration(
                gradient: _previewGradient,
              ),
              child: Stack(
                children: [
                  // Grid paper
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.07,
                      child: GridPaper(
                        color: AppColors.white,
                        divisions: 1,
                        interval: 16,
                        subdivisions: 1,
                      ),
                    ),
                  ),
                  // Role badge
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.white.withValues(alpha: 0.20),
                        border: Border.all(
                            color: AppColors.white.withValues(alpha: 0.30),
                            width: 0.5),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusPill),
                      ),
                      child: const Text(
                        'ADMIN',
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  // Album name
                  Positioned(
                    bottom: 10,
                    left: 12,
                    right: 12,
                    child: Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppTheme.headingFont,
                        color: AppColors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        shadows: [
                          Shadow(
                              color: Colors.black26,
                              offset: Offset(0, 1),
                              blurRadius: 4)
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Meta row
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.photo_outlined,
                      size: 12,
                      color: AppColors.brightGold.withValues(alpha: 0.8)),
                  const SizedBox(width: 4),
                  const Text(
                    '0 files',
                    style: TextStyle(
                      color: AppColors.featherTaupe,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(Icons.group_outlined,
                      size: 12,
                      color: AppColors.featherTaupe.withValues(alpha: 0.7)),
                  const SizedBox(width: 4),
                  const Text(
                    '1 member',
                    style: TextStyle(
                      color: AppColors.featherTaupe,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
