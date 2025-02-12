import 'package:flutter/material.dart';
import '../../../../core/presentation/utils/snackbar_utils.dart';
import '../../domain/entities/media_asset.dart';
import '../bloc/media_bloc.dart';
import 'package:go_router/go_router.dart';
import 'video_preview.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/repositories/video_overlay_repository_impl.dart';
import 'package:provider/provider.dart';

class MediaGrid extends StatelessWidget {
  final List<MediaAsset> assets;
  final Future<void> Function() onRefresh;

  const MediaGrid({
    Key? key,
    required this.assets,
    required this.onRefresh,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (assets.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.movie_creation_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 8),
              Text(
                'Upload your first video or audio file',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    return SliverLayoutBuilder(
      builder: (context, constraints) {
        return SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 400,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 16 / 9,
              mainAxisExtent: constraints.crossAxisExtent > 400 ? 300 : 200,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final asset = assets[index];
                return GestureDetector(
                  onTap: () {
                    if (asset.type == MediaType.rawFootage ||
                        asset.type == MediaType.editedClip) {
                      showDialog(
                        context: context,
                        useSafeArea: true,
                        barrierDismissible: true,
                        builder: (context) => Dialog.fullscreen(
                          child: Provider(
                            create: (context) => VideoOverlayRepositoryImpl(
                              firestore: FirebaseFirestore.instance,
                              auth: FirebaseAuth.instance,
                            ),
                            child: VideoPreview(
                              mediaAsset: asset,
                            ),
                          ),
                        ),
                      );
                    }
                  },
                  child: _MediaTile(asset: asset),
                );
              },
              childCount: assets.length,
            ),
          ),
        );
      },
    );
  }
}

class _MediaTile extends StatelessWidget {
  final MediaAsset asset;

  const _MediaTile({
    required this.asset,
  });

  Future<void> _handleDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline, color: Colors.red),
        title: const Text('Delete Media'),
        content: Text(
          'Are you sure you want to delete "${asset.fileName}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      context.read<MediaBloc>().add(DeleteMedia(asset));
      showSuccessSnackBar(context, 'Media deleted successfully');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (asset.thumbnailUrl != null)
            Image.network(
              asset.thumbnailUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Icon(
                    Icons.movie,
                    size: 48,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                );
              },
            )
          else
            Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Icon(
                Icons.movie,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          if (asset.type == MediaType.rawFootage ||
              asset.type == MediaType.editedClip)
            Positioned(
              right: 8,
              bottom: 8,
              child: Icon(
                Icons.play_circle_fill,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton.filledTonal(
              onPressed: () => _handleDelete(context),
              icon: const Icon(Icons.delete_outline),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black45,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
              padding: const EdgeInsets.all(8.0),
              child: Text(
                asset.fileName,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
