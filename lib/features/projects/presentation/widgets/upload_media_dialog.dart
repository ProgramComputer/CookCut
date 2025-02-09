import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/media_bloc.dart';
import 'media_import_widget.dart';
import '../../data/repositories/media_repository_impl.dart';
import '../../data/services/media_processing_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UploadMediaDialog extends StatelessWidget {
  final String projectId;

  const UploadMediaDialog({
    super.key,
    required this.projectId,
  });

  @override
  Widget build(BuildContext context) {
    final mediaProcessingService = MediaProcessingService(
      supabase: Supabase.instance.client,
    );

    final mediaRepository = MediaRepositoryImpl(
      firestore: FirebaseFirestore.instance,
      supabase: Supabase.instance.client,
      auth: FirebaseAuth.instance,
      mediaProcessingService: mediaProcessingService,
    );

    return Dialog(
      backgroundColor: Theme.of(context).colorScheme.surface,
      surfaceTintColor: Theme.of(context).colorScheme.surfaceTint,
      child: BlocProvider(
        create: (context) => MediaBloc(
          mediaRepository: mediaRepository,
        ),
        child: BlocListener<MediaBloc, MediaState>(
          listener: (context, state) {
            if (state.status == MediaStatus.success &&
                state.assets.isNotEmpty) {
              // Notify parent to refresh media list
              context.read<MediaBloc>().add(LoadProjectMedia(projectId));
              // Show success message
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Media uploaded successfully'),
                  backgroundColor: Colors.green,
                ),
              );
              // Close dialog
              Navigator.of(context).pop();
            } else if (state.status == MediaStatus.error &&
                state.error != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.error!),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          child: Container(
            width: 600,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Import Media',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                MediaImportWidget(
                  projectId: projectId,
                  width: 552, // 600 - (24 * 2) padding
                  height: 300,
                ),
                BlocBuilder<MediaBloc, MediaState>(
                  builder: (context, state) {
                    if (state.status == MediaStatus.loading) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24.0),
                        child: Column(
                          children: [
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Uploading media...',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'This may take a while depending on the file size',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
