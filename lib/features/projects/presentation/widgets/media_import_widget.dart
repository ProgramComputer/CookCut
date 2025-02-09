import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:mime/mime.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:developer' as developer;
import '../bloc/media_bloc.dart';
import '../../domain/entities/media_asset.dart';
import 'package:image_picker/image_picker.dart';
import '../../domain/entities/video_processing_config.dart';
import 'dart:async';

class MediaImportWidget extends StatefulWidget {
  final String projectId;
  final double? width;
  final double? height;

  const MediaImportWidget({
    super.key,
    required this.projectId,
    this.width,
    this.height,
  });

  @override
  State<MediaImportWidget> createState() => _MediaImportWidgetState();
}

class _MediaImportWidgetState extends State<MediaImportWidget>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  String? _error;
  MediaType _selectedType = MediaType.rawFootage;
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setError(String error) {
    setState(() {
      _error = error;
      _isLoading = false;
    });
  }

  void _clearError() {
    setState(() => _error = null);
  }

  Future<void> _pickFile() async {
    _clearError();
    try {
      setState(() => _isLoading = true);

      final FileType fileType;
      final List<String> allowedExtensions;

      switch (_selectedType) {
        case MediaType.rawFootage:
        case MediaType.editedClip:
          fileType = FileType.video;
          allowedExtensions = ['mp4', 'mov', 'avi'];
          break;
        case MediaType.audio:
          fileType = FileType.custom;
          allowedExtensions = ['mp3', 'wav', 'm4a', 'aac'];
          break;
      }

      final result = await FilePicker.platform.pickFiles(
        type: fileType,
        allowedExtensions:
            fileType == FileType.custom ? allowedExtensions : null,
        allowMultiple: false,
      );

      if (!mounted) return;

      if (result != null && result.files.isNotEmpty) {
        final file = File(result.files.first.path!);
        await _validateAndProcessFile(file);
      } else {
        _setError('Please select a file to upload');
      }
    } catch (e) {
      developer.log(
        'Error picking file: $e',
        name: 'MediaImportWidget',
      );
      if (mounted) {
        _setError('Error selecting file: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _captureMedia() async {
    _clearError();
    try {
      setState(() => _isLoading = true);
      final picker = ImagePicker();

      final XFile? mediaFile;
      switch (_selectedType) {
        case MediaType.rawFootage:
        case MediaType.editedClip:
          mediaFile = await picker.pickVideo(source: ImageSource.camera);
          break;
        case MediaType.audio:
          _setError('Capture not supported for audio');
          return;
      }

      if (!mounted) return;

      if (mediaFile != null) {
        final file = File(mediaFile.path);
        await _validateAndProcessFile(file);
      }
    } catch (e) {
      developer.log(
        'Error capturing media: $e',
        name: 'MediaImportWidget',
      );
      if (mounted) {
        _setError('Error capturing media: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _validateAndProcessFile(File file) async {
    try {
      final mimeType = lookupMimeType(file.path);
      final extension = file.path.split('.').last.toLowerCase();
      developer.log(
          'Validating file: ${file.path}, mime type: $mimeType, extension: $extension',
          name: 'MediaImportWidget');

      if (_selectedType == MediaType.audio) {
        if (!['mp3', 'wav', 'm4a', 'aac'].contains(extension)) {
          _setError(
              'Unsupported audio format. Please use MP3, WAV, M4A, or AAC files.');
          return;
        }
      } else if (_selectedType == MediaType.rawFootage ||
          _selectedType == MediaType.editedClip) {
        if (!['mp4', 'mov', 'avi'].contains(extension)) {
          _setError(
              'Unsupported video format. Please use MP4, MOV, or AVI files.');
          return;
        }
      }

      // Direct upload for all files
      setState(() => _isLoading = true);
      context.read<MediaBloc>().add(
            UploadMedia(
              projectId: widget.projectId,
              filePath: file.path,
              type: _selectedType,
              metadata: {
                'fileType':
                    _selectedType == MediaType.audio ? 'audio' : 'video',
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

  String _getFileSupportText() {
    switch (_selectedType) {
      case MediaType.rawFootage:
      case MediaType.editedClip:
        return 'Supports MP4 and MOV video files';
      case MediaType.audio:
        return 'Supports MP3, WAV, and M4A audio files';
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isSmallScreen = mediaQuery.size.width < 600;
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: BlocListener<MediaBloc, MediaState>(
        listener: (context, state) {
          if (state.status == MediaStatus.error && state.error != null) {
            developer.log(
              'MediaBloc error: ${state.error}',
              name: 'MediaImportWidget',
            );
            _setError(state.error!);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!isSmallScreen) ...[
                SegmentedButton<MediaType>(
                  segments: const [
                    ButtonSegment<MediaType>(
                      value: MediaType.rawFootage,
                      label: Text('Raw Footage'),
                      icon: Icon(Icons.videocam_outlined),
                    ),
                    ButtonSegment<MediaType>(
                      value: MediaType.editedClip,
                      label: Text('Edited Clip'),
                      icon: Icon(Icons.movie_outlined),
                    ),
                    ButtonSegment<MediaType>(
                      value: MediaType.audio,
                      label: Text('Audio'),
                      icon: Icon(Icons.audiotrack_outlined),
                    ),
                  ],
                  selected: {_selectedType},
                  onSelectionChanged: (Set<MediaType> selection) {
                    setState(() => _selectedType = selection.first);
                  },
                ),
                const SizedBox(height: 16),
              ],
              Container(
                width: widget.width ?? double.infinity,
                height: widget.height ?? (isSmallScreen ? 200 : 300),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_selectedType != MediaType.audio) ...[
                      GestureDetector(
                        onTapDown: (_) => _controller.forward(),
                        onTapUp: (_) => _controller.reverse(),
                        onTapCancel: () => _controller.reverse(),
                        child: ScaleTransition(
                          scale: _scaleAnimation,
                          child: IconButton.filled(
                            onPressed: _captureMedia,
                            icon: const Icon(Icons.camera_alt_outlined),
                            iconSize: 32,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('Capture Video'),
                      const Text('or'),
                    ],
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: _pickFile,
                      icon: const Icon(Icons.upload_file),
                      label: Text(_selectedType == MediaType.audio
                          ? 'Upload Audio'
                          : 'Upload Video'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getFileSupportText(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
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
            ],
          ),
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
