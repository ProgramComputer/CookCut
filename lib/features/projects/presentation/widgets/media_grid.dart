import 'package:flutter/material.dart';
import '../../../../core/presentation/utils/snackbar_utils.dart';
import '../../domain/entities/media_asset.dart';
import '../bloc/media_bloc.dart';
import 'package:go_router/go_router.dart';
import 'video_preview.dart';
import 'audio_preview.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/repositories/video_overlay_repository_impl.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import '../../domain/repositories/media_repository.dart';

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
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final asset = assets[index];
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final tileHeight = constraints.maxWidth > 400
                        ? asset.type == MediaType.audio
                            ? 100.0
                            : 400.0
                        : asset.type == MediaType.audio
                            ? 80.0
                            : 300.0;
                    return SizedBox(
                      height: tileHeight,
                      child: GestureDetector(
                        onTap: () {
                          if (asset.type == MediaType.rawFootage ||
                              asset.type == MediaType.editedClip) {
                            showDialog(
                              context: context,
                              useSafeArea: true,
                              barrierDismissible: true,
                              builder: (context) => Dialog.fullscreen(
                                child: Provider(
                                  create: (context) =>
                                      VideoOverlayRepositoryImpl(
                                    firestore: FirebaseFirestore.instance,
                                    auth: FirebaseAuth.instance,
                                  ),
                                  child: VideoPreview(
                                    mediaAsset: asset,
                                  ),
                                ),
                              ),
                            );
                          } else if (asset.type == MediaType.audio) {
                            showDialog(
                              context: context,
                              builder: (context) => AudioPreview(
                                mediaAsset: asset,
                              ),
                            );
                          }
                        },
                        child: _MediaTile(asset: asset),
                      ),
                    );
                  },
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
    Key? key,
    required this.asset,
  }) : super(key: key);

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

  Future<void> _handleDownload(BuildContext context) async {
    try {
      // Request storage permission on Android
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content:
                    Text('Storage permission is required to download videos'),
              ),
            );
          }
          return;
        }
      }

      // Show progress indicator
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Downloading video...'),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Get the download URL using MediaRepository
      final mediaRepository = context.read<MediaBloc>().mediaRepository;
      final downloadUrl = await mediaRepository.getDownloadUrl(asset);

      // Download the file
      final response = await http.get(Uri.parse(downloadUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to download file');
      }

      // Get the downloads directory
      final directory = Platform.isAndroid
          ? Directory('/storage/emulated/0/Download')
          : await getApplicationDocumentsDirectory();

      // Create the file
      final file = File('${directory.path}/${asset.fileName}');
      await file.writeAsBytes(response.bodyBytes);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded to ${file.path}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading file: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
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
                    asset.type == MediaType.audio
                        ? Icons.audio_file
                        : Icons.movie,
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
                asset.type == MediaType.audio ? Icons.audio_file : Icons.movie,
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
          if (asset.type == MediaType.editedClip)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .secondaryContainer
                      .withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.content_cut,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Trimmed',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSecondaryContainer,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          if (asset.duration != null &&
              (asset.type == MediaType.rawFootage ||
                  asset.type == MediaType.editedClip))
            Positioned(
              right: 8,
              bottom: 40,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  asset.formattedDuration,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                      ),
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
          if (asset.type == MediaType.rawFootage ||
              asset.type == MediaType.editedClip)
            Positioned(
              top: 8,
              right: 48,
              child: IconButton.filledTonal(
                onPressed: () => _handleDownload(context),
                icon: const Icon(Icons.download),
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
}
