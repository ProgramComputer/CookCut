import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../domain/entities/project.dart';
import '../../domain/entities/media_asset.dart';
import '../bloc/media_bloc.dart';
import '../widgets/upload_media_dialog.dart';
import '../widgets/video_import_widget.dart';
import '../widgets/media_grid.dart';
import '../../../../core/presentation/utils/snackbar_utils.dart';
import '../../data/repositories/media_repository_impl.dart';
import '../../data/services/media_processing_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProjectDetailPage extends StatelessWidget {
  final String projectId;
  final Project project;

  const ProjectDetailPage({
    super.key,
    required this.projectId,
    required this.project,
  });

  void _showUploadDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => UploadMediaDialog(projectId: projectId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaProcessingService = MediaProcessingService(
      supabase: Supabase.instance.client,
    );

    final mediaRepository = MediaRepositoryImpl(
      mediaProcessingService: mediaProcessingService,
    );

    return BlocProvider(
      create: (context) => MediaBloc(
        mediaRepository: mediaRepository,
      )..add(LoadProjectMedia(projectId)),
      child: Scaffold(
        appBar: AppBar(
          title: Text(project.title),
          actions: [
            IconButton(
              icon: const Icon(Icons.people_outline),
              tooltip: 'Collaborators',
              onPressed: () {
                // TODO: Implement collaborators
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Collaborators coming soon')),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.analytics_outlined),
              tooltip: 'Analytics',
              onPressed: () {
                // TODO: Implement analytics
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Analytics coming soon')),
                );
              },
            ),
          ],
        ),
        body: BlocBuilder<MediaBloc, MediaState>(
          builder: (context, state) {
            if (state.status == MediaStatus.loading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state.status == MediaStatus.error) {
              return Center(
                child: Text(
                  state.error ?? 'An error occurred',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Project Details',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        project.description,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Media',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      FilledButton.icon(
                        onPressed: () => _showUploadDialog(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Media'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: MediaGrid(
                    assets: state.assets,
                    onRefresh: () {
                      context
                          .read<MediaBloc>()
                          .add(LoadProjectMedia(projectId));
                    },
                  ),
                ),
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/projects/$projectId/import'),
          icon: const Icon(Icons.videocam),
          label: const Text('Import Video'),
        ),
      ),
    );
  }
}
