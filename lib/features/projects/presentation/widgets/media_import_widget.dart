import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:mime/mime.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:developer' as developer;
import '../bloc/media_bloc.dart';
import '../../domain/entities/media_asset.dart';
import '../../domain/entities/project.dart';
import 'package:image_picker/image_picker.dart';
import 'audio_recording_dialog.dart';
import 'generate_stock_video_dialog.dart';

class MediaImportWidget extends StatefulWidget {
  final String projectId;
  final Project project;

  const MediaImportWidget({
    super.key,
    required this.projectId,
    required this.project,
  });

  @override
  State<MediaImportWidget> createState() => _MediaImportWidgetState();
}

class _MediaImportWidgetState extends State<MediaImportWidget> {
  bool _isLoading = false;
  String? _error;

  void _setError(String error) {
    setState(() {
      _error = error;
      _isLoading = false;
    });
  }

  void _clearError() {
    setState(() => _error = null);
  }

  Future<void> _importMedia() async {
    _clearError();
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowedExtensions: null,
        allowMultiple: false,
      );

      if (!mounted) return;

      if (result != null && result.files.isNotEmpty) {
        final file = File(result.files.first.path!);
        await _validateAndProcessFile(file);
      }
    } catch (e) {
      developer.log(
        'Error picking file: $e',
        name: 'MediaImportWidget',
      );
      if (mounted) {
        _setError('Error selecting file: $e');
      }
    }
  }

  Future<void> _showRecordingOptions() async {
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('Record Video'),
              onTap: () {
                Navigator.pop(context);
                _recordVideo();
              },
            ),
            ListTile(
              leading: const Icon(Icons.mic_outlined),
              title: const Text('Record Audio'),
              onTap: () {
                Navigator.pop(context);
                _recordAudio();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _recordVideo() async {
    _clearError();
    try {
      setState(() => _isLoading = true);

      final picker = ImagePicker();
      final mediaFile = await picker.pickVideo(source: ImageSource.camera);

      if (!mounted) return;

      if (mediaFile != null) {
        final file = File(mediaFile.path);
        await _validateAndProcessFile(file);
      }
    } catch (e) {
      developer.log(
        'Error recording video: $e',
        name: 'MediaImportWidget',
      );
      if (mounted) {
        _setError('Error recording video: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _recordAudio() async {
    _clearError();
    try {
      setState(() => _isLoading = true);

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AudioRecordingDialog(
          onRecordingComplete: (String filePath) async {
            final file = File(filePath);
            if (await file.exists()) {
              await _validateAndProcessFile(file);
            }
          },
        ),
      );
    } catch (e) {
      developer.log(
        'Error recording audio: $e',
        name: 'MediaImportWidget',
      );
      if (mounted) {
        _setError('Error recording audio: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showGenerateVideoDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: context.read<MediaBloc>(),
        child: GenerateStockVideoDialog(
          project: widget.project,
          onVideoGenerated: (mediaAsset) {
            context.read<MediaBloc>().add(
                  AddGeneratedMedia(mediaAsset),
                );
          },
        ),
      ),
    );
  }

  Future<void> _validateAndProcessFile(File file) async {
    try {
      final mimeType = lookupMimeType(file.path);
      final extension = file.path.split('.').last.toLowerCase();

      developer.log(
          'Validating file: ${file.path}, mime type: $mimeType, extension: $extension',
          name: 'MediaImportWidget');

      // Determine media type from mime type
      final MediaType mediaType;
      if (['mp3', 'wav', 'm4a', 'aac'].contains(extension)) {
        mediaType = MediaType.audio;
      } else if (['mp4', 'mov', 'avi'].contains(extension)) {
        mediaType = MediaType.rawFootage;
      } else {
        _setError(
            'Unsupported file format. Please use MP4, MOV, AVI for video or MP3, WAV, M4A, AAC for audio.');
        return;
      }

      // Show immediate feedback
      setState(() => _isLoading = true);

      // Add a small delay to show the loading state
      await Future.delayed(const Duration(milliseconds: 300));

      if (!mounted) return;

      // Upload the file
      context.read<MediaBloc>().add(
            UploadMedia(
              projectId: widget.projectId,
              filePath: file.path,
              type: mediaType,
              metadata: {
                'fileType': mediaType == MediaType.audio ? 'audio' : 'video',
                'extension': extension,
                'projectId': widget.projectId,
              },
            ),
          );
    } catch (e) {
      developer.log(
        'Error processing file: $e',
        name: 'MediaImportWidget',
      );
      if (mounted) {
        _setError('Error processing file: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: BlocListener<MediaBloc, MediaState>(
        listener: (context, state) {
          if (state.status == MediaStatus.success) {
            setState(() => _isLoading = false);
          } else if (state.status == MediaStatus.error && state.error != null) {
            developer.log(
              'MediaBloc error: ${state.error}',
              name: 'MediaImportWidget',
            );
            _setError(state.error!);
          }
        },
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FloatingActionButton.extended(
                        heroTag: 'import_media',
                        onPressed: _importMedia,
                        icon: const Icon(Icons.add),
                        label: const Text('Import Media'),
                      ),
                      FloatingActionButton(
                        heroTag: 'record_media',
                        onPressed: _showRecordingOptions,
                        child: const Icon(Icons.fiber_manual_record),
                      ),
                      FloatingActionButton.extended(
                        heroTag: 'generate_video',
                        onPressed: _showGenerateVideoDialog,
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('Generate Stock Video'),
                      ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
            if (_isLoading)
              Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ErrorBoundary extends StatelessWidget {
  final Widget child;
  final Widget Function(Object error, StackTrace? stack) onError;

  const ErrorBoundary({
    super.key,
    required this.child,
    required this.onError,
  });

  @override
  Widget build(BuildContext context) {
    ErrorWidget.builder = (FlutterErrorDetails details) {
      return onError(details.exception, details.stack);
    };
    return child;
  }
}
