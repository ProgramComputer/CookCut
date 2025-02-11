import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../bloc/media_bloc.dart';
import 'media_import_widget.dart';
import '../../data/repositories/media_repository_impl.dart';
import '../../data/services/media_processing_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/media_asset.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';

class UploadMediaDialog extends StatefulWidget {
  final String projectId;

  const UploadMediaDialog({
    super.key,
    required this.projectId,
  });

  @override
  State<UploadMediaDialog> createState() => _UploadMediaDialogState();
}

class _UploadMediaDialogState extends State<UploadMediaDialog> {
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
              // Close dialog first to prevent UI jank
              context.pop();
              // Show success message
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Media uploaded successfully'),
                  backgroundColor: Colors.green,
                ),
              );
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
            width: 400,
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Import Media',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => context.pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 300,
                  child: MediaImportWidget(
                    projectId: widget.projectId,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
