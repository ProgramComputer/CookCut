import 'package:flutter/material.dart';
import '../../../../core/presentation/utils/snackbar_utils.dart';
import '../../domain/entities/media_asset.dart';
import '../bloc/media_bloc.dart';
import 'package:go_router/go_router.dart';
import 'video_preview.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class MediaGrid extends StatelessWidget {
  final List<MediaAsset> assets;
  final VoidCallback? onRefresh;

  const MediaGrid({
    super.key,
    required this.assets,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (assets.isEmpty) {
      return Center(
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
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        onRefresh?.call();
      },
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 400,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 16 / 9,
        ),
        itemCount: assets.length,
        itemBuilder: (context, index) {
          final asset = assets[index];
          return _MediaTile(asset: asset);
        },
      ),
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
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.withOpacity(0.1),
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!context.mounted) return;
      context.read<MediaBloc>().add(DeleteMedia(asset));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (asset.type == MediaType.rawFootage ||
              asset.type == MediaType.editedClip)
            VideoPreview(mediaAsset: asset)
          else
            Center(
              child: Icon(
                _getIconForType(asset.type),
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
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
        ],
      ),
    );
  }

  IconData _getIconForType(MediaType type) {
    switch (type) {
      case MediaType.rawFootage:
        return Icons.videocam_outlined;
      case MediaType.editedClip:
        return Icons.movie_outlined;
      case MediaType.audio:
        return Icons.audiotrack_outlined;
      case MediaType.overlay:
        return Icons.layers_outlined;
      case MediaType.thumbnail:
        return Icons.image_outlined;
    }
  }
}
