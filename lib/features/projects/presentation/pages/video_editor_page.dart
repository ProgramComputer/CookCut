import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:just_audio/just_audio.dart';

import '../widgets/video_overlay_renderer.dart';
import '../widgets/overlay_toolbar.dart';
import '../widgets/text_overlay_editor.dart';
import '../widgets/timer_overlay_editor.dart';
import '../widgets/video_trim_widget.dart';
import '../widgets/background_music_browser.dart';
import '../widgets/comment_panel.dart';
import '../bloc/video_comment_bloc.dart';

import '../../domain/entities/text_overlay.dart';
import '../../domain/entities/timer_overlay.dart';
import '../../domain/entities/media_asset.dart';

import '../../data/repositories/video_overlay_repository_impl.dart';
import '../../data/repositories/video_comment_repository_impl.dart';
import '../../data/models/video_overlay_model.dart';
import '../../data/services/video_export_service.dart';

class VideoEditorPage extends StatefulWidget {
  final String videoUrl;
  final String projectId;
  final double aspectRatio;
  final bool startInPreviewMode;

  const VideoEditorPage({
    Key? key,
    required this.videoUrl,
    required this.projectId,
    this.aspectRatio = 16 / 9,
    this.startInPreviewMode = false,
  }) : super(key: key);

  @override
  State<VideoEditorPage> createState() => _VideoEditorPageState();
}

class _VideoEditorPageState extends State<VideoEditorPage>
    with SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  late VideoOverlayRepositoryImpl _overlayRepository;
  late VideoExportService _exportService;
  late AnimationController _modeTransitionController;
  late Animation<double> _editorControlsOpacity;

  // Audio state
  AudioPlayer? _musicPlayer;
  double _videoVolume = 1.0;
  double _musicVolume = 1.0;
  String? _backgroundMusicUrl;

  TextOverlay? _selectedTextOverlay;
  TimerOverlay? _selectedTimerOverlay;
  bool _isExporting = false;
  bool _isPreviewMode = false;
  bool _isControlsVisible = true;
  bool _showComments = false;
  bool _isInitialized = false;

  // Cache the video duration to avoid rebuilds
  String? _cachedDuration;
  String? _cachedPosition;

  @override
  void initState() {
    super.initState();
    _isPreviewMode = widget.startInPreviewMode;

    // Initialize animation controller
    _modeTransitionController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _editorControlsOpacity =
        Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _modeTransitionController,
      curve: Curves.easeInOut,
    ));

    // Set initial animation state
    if (_isPreviewMode) {
      _modeTransitionController.value = 0.0;
    } else {
      _modeTransitionController.value = 1.0;
    }

    // Initialize repositories
    _overlayRepository = VideoOverlayRepositoryImpl(
      firestore: FirebaseFirestore.instance,
      auth: FirebaseAuth.instance,
    );
    _exportService = VideoExportService(overlayRepository: _overlayRepository);

    // Initialize audio
    _initializeAudio();

    // Initialize video after build completes to avoid ScaffoldMessenger errors
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeVideoPlayer();
    });
  }

  Future<void> _initializeVideoPlayer() async {
    try {
      // Ensure any existing controller is properly disposed
      if (_controller != null) {
        await _controller!.pause();
        _controller!.removeListener(_updatePosition);
        await Future.delayed(const Duration(milliseconds: 500));
        await _controller!.dispose();
      }

      final controller = VideoPlayerController.network(
        widget.videoUrl,
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
          allowBackgroundPlayback: false,
        ),
      );

      // Wait for any previous instance to be fully cleaned up
      await Future.delayed(const Duration(milliseconds: 100));

      // Initialize with error handling
      try {
        await controller.initialize();
      } catch (e) {
        controller.dispose();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Error initializing video: ${e.toString()}')),
          );
        }
        return;
      }

      if (!mounted) {
        controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _isInitialized = true;
        _cachedDuration = _formatDuration(controller.value.duration);
      });

      if (_isPreviewMode) {
        controller.play();
      }
      controller.addListener(_updatePosition);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error initializing video: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _initializeAudio() async {
    _musicPlayer = AudioPlayer();
  }

  void _updatePosition() {
    if (!mounted) return;
    final newPosition = _formatDuration(_controller!.value.position);
    if (newPosition != _cachedPosition) {
      setState(() {
        _cachedPosition = newPosition;
      });
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _updateVideoVolume(double value) {
    setState(() {
      _videoVolume = value;
      _controller!.setVolume(value);
    });
  }

  void _updateMusicVolume(double value) {
    setState(() {
      _musicVolume = value;
      _musicPlayer?.setVolume(value);
    });
  }

  Future<void> _onBackgroundMusicSelected(String url) async {
    try {
      await _musicPlayer?.stop();
      await _musicPlayer?.setUrl(url);
      await _musicPlayer?.setVolume(_musicVolume);
      await _musicPlayer?.play();
      setState(() {
        _backgroundMusicUrl = url;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error playing background music: ${e.toString()}')),
      );
    }
  }

  @override
  void dispose() {
    final controller = _controller;
    if (controller != null) {
      // Ensure proper cleanup of video resources
      controller.pause();
      controller.removeListener(_updatePosition);
      // Add longer delay and proper error handling for MediaCodec cleanup
      Future.delayed(const Duration(milliseconds: 500), () {
        try {
          controller.dispose();
        } catch (e) {
          debugPrint('Error disposing video controller: $e');
        }
      });
    }

    _modeTransitionController.dispose();
    _musicPlayer?.dispose();
    super.dispose();
  }

  void _toggleEditMode() {
    setState(() {
      _isPreviewMode = !_isPreviewMode;
      if (_isPreviewMode) {
        _modeTransitionController.reverse();
      } else {
        _modeTransitionController.forward();
        // Ensure controls are visible in edit mode
        _isControlsVisible = true;
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _isControlsVisible = !_isControlsVisible;
    });
  }

  void _toggleComments() {
    setState(() {
      _showComments = !_showComments;
    });
  }

  void _showTrimDialog() {
    showDialog(
      context: context,
      useSafeArea: false,
      barrierDismissible: false,
      builder: (context) => VideoTrimWidget(
        mediaAsset: MediaAsset(
          id: 'temp',
          projectId: widget.projectId,
          type: MediaType.rawFootage,
          fileUrl: widget.videoUrl,
          fileName: 'video.mp4',
          position: 0,
          fileSize: 0,
          uploadedAt: DateTime.now(),
        ),
        onTrimComplete: (String trimmedVideoUrl) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Video trimmed successfully')),
          );
        },
      ),
    );
  }

  Future<void> _exportVideo() async {
    try {
      setState(() {
        _isExporting = true;
      });

      final outputPath = await _exportService.exportVideoWithOverlays(
        projectId: widget.projectId,
        inputVideoPath: widget.videoUrl,
        aspectRatio: widget.aspectRatio,
      );

      // Show success dialog with the output path
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Export Complete'),
          content: Text('Video exported to: $outputPath'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      // Show error dialog
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Export Failed'),
          content: Text(e.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      setState(() {
        _isExporting = false;
      });
    }
  }

  void _onAddText(TextOverlay overlay) async {
    await _overlayRepository.addTextOverlay(widget.projectId, overlay);
    setState(() {
      _selectedTextOverlay = overlay;
      _selectedTimerOverlay = null;
    });
  }

  void _onAddTimer(TimerOverlay overlay) async {
    await _overlayRepository.addTimerOverlay(widget.projectId, overlay);
    setState(() {
      _selectedTimerOverlay = overlay;
      _selectedTextOverlay = null;
    });
  }

  void _onTextDragEnd(TextOverlay overlay, Offset position) async {
    final updated = overlay.copyWith(
      x: position.dx,
      y: position.dy,
    );
    await _overlayRepository.updateTextOverlay(widget.projectId, updated);
  }

  void _onTimerDragEnd(TimerOverlay overlay, Offset position) async {
    final updated = overlay.copyWith(
      x: position.dx,
      y: position.dy,
    );
    await _overlayRepository.updateTimerOverlay(widget.projectId, updated);
  }

  @override
  Widget build(BuildContext context) {
    // Show loading state until initialization completes
    if (!_isInitialized || _controller == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final size = MediaQuery.of(context).size;
    final videoWidth = size.width;
    final videoHeight = videoWidth / widget.aspectRatio;

    return MultiProvider(
      providers: [
        Provider<VideoOverlayRepositoryImpl>.value(
          value: _overlayRepository,
        ),
        BlocProvider(
          create: (context) => VideoCommentBloc(
            commentRepository: VideoCommentRepositoryImpl(
              firestore: FirebaseFirestore.instance,
              auth: FirebaseAuth.instance,
            ),
          ),
        ),
      ],
      child: Builder(
        builder: (context) {
          return Scaffold(
            appBar: _isPreviewMode && !_isControlsVisible
                ? null
                : AppBar(
                    title: Text(_isPreviewMode ? 'Preview' : 'Edit Video'),
                    actions: [
                      IconButton(
                        icon: Icon(_isPreviewMode
                            ? Icons.edit
                            : Icons.preview_outlined),
                        onPressed: _toggleEditMode,
                        tooltip: _isPreviewMode
                            ? 'Switch to Edit Mode'
                            : 'Switch to Preview Mode',
                      ),
                      if (!_isPreviewMode)
                        if (_isExporting)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16.0),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              ),
                            ),
                          )
                        else
                          IconButton(
                            icon: const Icon(Icons.save),
                            onPressed: _exportVideo,
                            tooltip: 'Export video with overlays',
                          ),
                    ],
                  ),
            body: Column(
              children: [
                // Video Preview with Overlays
                GestureDetector(
                  onTap: _toggleControls,
                  child: SizedBox(
                    width: videoWidth,
                    height: videoHeight,
                    child: Stack(
                      children: [
                        // Video Player
                        AspectRatio(
                          aspectRatio: widget.aspectRatio,
                          child: VideoPlayer(_controller!),
                        ),
                        // Overlays
                        if (!_isPreviewMode)
                          FadeTransition(
                            opacity: _editorControlsOpacity,
                            child: StreamBuilder<List<VideoOverlayModel>>(
                              stream: _overlayRepository
                                  .watchProjectOverlays(widget.projectId),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const SizedBox.shrink();
                                }

                                final overlays = snapshot.data!;
                                final textOverlays = overlays
                                    .where((o) => o.type == 'text')
                                    .map((o) => o.toTextOverlay())
                                    .toList();
                                final timerOverlays = overlays
                                    .where((o) => o.type == 'timer')
                                    .map((o) => o.toTimerOverlay())
                                    .toList();

                                return VideoOverlayRenderer(
                                  textOverlays: textOverlays,
                                  timerOverlays: timerOverlays,
                                  currentTime: _controller!
                                      .value.position.inSeconds
                                      .toDouble(),
                                  videoWidth: videoWidth,
                                  videoHeight: videoHeight,
                                  isEditing: true,
                                  onTextDragEnd: _onTextDragEnd,
                                  onTimerDragEnd: _onTimerDragEnd,
                                );
                              },
                            ),
                          ),
                        // Video Controls
                        if (_isControlsVisible)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_isPreviewMode)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8.0),
                                    child: Row(
                                      children: [
                                        IconButton.filledTonal(
                                          onPressed: _showTrimDialog,
                                          icon: const Icon(Icons.cut),
                                          style: IconButton.styleFrom(
                                            backgroundColor: Colors.black45,
                                            foregroundColor: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton.filledTonal(
                                          onPressed: _toggleComments,
                                          icon: Icon(_showComments
                                              ? Icons.comment
                                              : Icons.comment_outlined),
                                          style: IconButton.styleFrom(
                                            backgroundColor: Colors.black45,
                                            foregroundColor: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton.filledTonal(
                                          onPressed: () {
                                            showModalBottomSheet(
                                              context: context,
                                              isScrollControlled: true,
                                              backgroundColor:
                                                  Colors.transparent,
                                              builder: (context) =>
                                                  BackgroundMusicBrowser(
                                                onMusicSelected:
                                                    _onBackgroundMusicSelected,
                                                onCancel: () =>
                                                    Navigator.pop(context),
                                              ),
                                            );
                                          },
                                          icon: const Icon(Icons.music_note),
                                          style: IconButton.styleFrom(
                                            backgroundColor: Colors.black45,
                                            foregroundColor: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                VideoProgressIndicator(
                                  _controller!,
                                  allowScrubbing: true,
                                  padding: const EdgeInsets.all(8),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // Comments Panel
                if (_showComments && _isPreviewMode)
                  SizedBox(
                    height: 400,
                    child: CommentPanel(
                      projectId: widget.projectId,
                      assetId: 'temp',
                      currentTime: _controller!.value.position,
                    ),
                  ),
                // Editor Controls (only show when not in preview mode)
                if (!_isPreviewMode)
                  Expanded(
                    child: Container(
                      color: Theme.of(context).colorScheme.surface,
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: OverlayToolbar(
                                onAddText: _onAddText,
                                onAddTimer: _onAddTimer,
                                videoWidth: videoWidth,
                                videoHeight: videoHeight,
                              ),
                            ),
                            if (_selectedTextOverlay != null)
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: TextOverlayEditor(
                                  overlay: _selectedTextOverlay!,
                                  onUpdate: (updated) async {
                                    await _overlayRepository.updateTextOverlay(
                                      widget.projectId,
                                      updated,
                                    );
                                    setState(() {
                                      _selectedTextOverlay = updated;
                                    });
                                  },
                                  onDelete: () async {
                                    await _overlayRepository.deleteOverlay(
                                      _selectedTextOverlay!.id,
                                    );
                                    setState(() {
                                      _selectedTextOverlay = null;
                                    });
                                  },
                                  videoWidth: videoWidth,
                                  videoHeight: videoHeight,
                                ),
                              ),
                            if (_selectedTimerOverlay != null)
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: TimerOverlayEditor(
                                  overlay: _selectedTimerOverlay!,
                                  onUpdate: (updated) async {
                                    await _overlayRepository.updateTimerOverlay(
                                      widget.projectId,
                                      updated,
                                    );
                                    setState(() {
                                      _selectedTimerOverlay = updated;
                                    });
                                  },
                                  onDelete: () async {
                                    await _overlayRepository.deleteOverlay(
                                      _selectedTimerOverlay!.id,
                                    );
                                    setState(() {
                                      _selectedTimerOverlay = null;
                                    });
                                  },
                                  videoWidth: videoWidth,
                                  videoHeight: videoHeight,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () {
                setState(() {
                  if (_controller!.value.isPlaying) {
                    _controller!.pause();
                    _musicPlayer?.pause();
                  } else {
                    _controller!.play();
                    _musicPlayer?.play();
                  }
                });
              },
              child: Icon(
                _controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
              ),
            ),
          );
        },
      ),
    );
  }
}
