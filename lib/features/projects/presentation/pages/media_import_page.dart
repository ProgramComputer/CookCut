import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../widgets/media_import_widget.dart';
import '../bloc/media_bloc.dart';
import '../../data/repositories/media_repository_impl.dart';
import '../../data/services/media_processing_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MediaImportPage extends StatelessWidget {
  final String projectId;

  const MediaImportPage({
    Key? key,
    required this.projectId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Initialize services with all required dependencies
    final mediaProcessingService = MediaProcessingService(
      supabase: Supabase.instance.client,
    );

    final mediaRepository = MediaRepositoryImpl(
      firestore: FirebaseFirestore.instance,
      supabase: Supabase.instance.client,
      auth: FirebaseAuth.instance,
      mediaProcessingService: mediaProcessingService,
    );

    return BlocProvider(
      create: (context) => MediaBloc(
        mediaRepository: mediaRepository,
      )..add(LoadProjectMedia(projectId)), // Load existing media on init
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Import Media'),
          elevation: 0,
        ),
        body: BlocListener<MediaBloc, MediaState>(
          listener: (context, state) {
            if (state.status == MediaStatus.success &&
                state.uploadProgress == null &&
                state.assets.isNotEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Media uploaded successfully'),
                  backgroundColor: Colors.green,
                ),
              );
              Navigator.of(context).pop(); // Return to project details
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
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  MediaImportWidget(
                    projectId: projectId,
                  ),
                  BlocBuilder<MediaBloc, MediaState>(
                    builder: (context, state) {
                      if (state.status == MediaStatus.loading) {
                        return Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            children: [
                              const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
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
      ),
    );
  }
}
