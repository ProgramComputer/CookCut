import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:just_audio/just_audio.dart';
import '../../domain/entities/media_asset.dart';
import 'video_trim_widget.dart';
import 'comment_panel.dart';
import 'comment_marker_overlay.dart';
import '../bloc/video_comment_bloc.dart';
import '../../domain/repositories/video_comment_repository.dart';
import '../../data/repositories/video_comment_repository_impl.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'background_music_browser.dart';

class VideoPreview extends StatefulWidget {
  final MediaAsset mediaAsset;

  const VideoPreview({
    super.key,
    required this.mediaAsset,
  });

  @override
  State<VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<VideoPreview> {
  VideoPlayerController? _controller;
  AudioPlayer? _musicPlayer;
  bool _isInitialized = false;
  bool _showTrimming = false;
  bool _isControlsVisible = true;
  bool _showComments = false;

  // Audio state
  double _videoVolume = 1.0;
  double _musicVolume = 1.0;
  String? _backgroundMusicUrl;

  // Cache the video duration to avoid rebuilds
  String? _cachedDuration;
  String? _cachedPosition;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
    _initializeAudio();
  }

  Future<void> _initializeAudio() async {
    _musicPlayer = AudioPlayer();
  }

  Future<void> _initializeVideo() async {
    try {
      if (_controller != null) {
        await _controller!.pause();
        _controller!.removeListener(_updatePosition);
        await Future.delayed(const Duration(milliseconds: 500));
        await _controller!.dispose();
        _controller = null;
      }

      // Validate URL
      final url = widget.mediaAsset.fileUrl;
      if (url.isEmpty) {
        throw Exception('Invalid video URL');
      }

      // Create controller with platform-specific options
      final controller = VideoPlayerController.network(
        url,
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
          allowBackgroundPlayback: false,
        ),
        httpHeaders: const {
          'Access-Control-Allow-Origin': '*',
        },
      );

      // Wait for any previous instance to be fully cleaned up
      await Future.delayed(const Duration(milliseconds: 100));

      // Initialize controller with error handling
      try {
        await controller.initialize();
        controller.addListener(_updatePosition);
        setState(() {
          _controller = controller;
          _isInitialized = true;
          _cachedDuration = _formatDuration(controller.value.duration);
        });
      } catch (e) {
        print('Error initializing video player: $e');
        await controller.dispose();
        rethrow;
      }

      if (!mounted) {
        await controller.dispose();
        return;
      }

      await controller.setPlaybackSpeed(1.0);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading video: ${e.toString()}')),
        );
      }
    }
  }

  void _updatePosition() {
    if (!mounted || _controller == null) return;
    final newPosition = _formatDuration(_controller!.value.position);
    if (newPosition != _cachedPosition) {
      setState(() {
        _cachedPosition = newPosition;
      });
    }
  }

  void _updateVideoVolume(double value) {
    setState(() {
      _videoVolume = value;
      _controller?.setVolume(value);
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
    if (_controller != null) {
      // Ensure video is paused before cleanup
      _controller!.pause();
      // Remove listener first to prevent callbacks during disposal
      _controller!.removeListener(_updatePosition);
      // Add a longer delay and proper error handling for MediaCodec cleanup
      Future.delayed(const Duration(milliseconds: 500), () {
        try {
          _controller!.dispose();
        } catch (e) {
          debugPrint('Error disposing video controller: $e');
        }
      });
    }
    _musicPlayer?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(VideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaAsset.fileUrl != widget.mediaAsset.fileUrl) {
      _isInitialized = false;
      // Stop background music when video changes
      _musicPlayer?.stop();
      _backgroundMusicUrl = null;
      _initializeVideo();
    }
  }

  void _showTrimDialog() {
    showDialog(
      context: context,
      useSafeArea: false,
      barrierDismissible: false,
      builder: (context) => VideoTrimWidget(
        mediaAsset: widget.mediaAsset,
        onTrimComplete: (String trimmedVideoUrl) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Video trimmed successfully')),
          );
        },
      ),
    );
  }

  void _toggleComments() {
    setState(() {
      _showComments = !_showComments;
    });
  }

  void _seekToComment(Duration position) {
    _controller?.seekTo(position);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (!_isInitialized || controller == null) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _isControlsVisible = !_isControlsVisible;
            });
          },
          behavior: HitTestBehavior.opaque,
          child: AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // Use RepaintBoundary for the video player
                RepaintBoundary(
                  child: VideoPlayer(controller),
                ),
                // Only build controls when visible
                if (_isControlsVisible)
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () {},
                      child: _OptimizedVideoControls(
                        controller: controller,
                        onPlayPause: () {
                          setState(() {
                            if (controller.value.isPlaying) {
                              controller.pause();
                              _musicPlayer?.pause();
                            } else {
                              controller.play();
                              _musicPlayer?.play();
                            }
                          });
                        },
                        position: _cachedPosition ?? '00:00',
                        duration: _cachedDuration ?? '00:00',
                        child: CommentMarkerOverlay(
                          videoDuration: controller.value.duration,
                          currentPosition: controller.value.position,
                          onMarkerTap: _seekToComment,
                        ),
                      ),
                    ),
                  ),
                if (_isControlsVisible)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: RepaintBoundary(
                      child: Row(
                        children: [
                          IconButton.filledTonal(
                            onPressed: () {
                              _showTrimDialog();
                              HapticFeedback.lightImpact();
                            },
                            icon: const Icon(Icons.cut),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.black45,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            onPressed: () {
                              _toggleComments();
                              HapticFeedback.lightImpact();
                            },
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
                                backgroundColor: Colors.transparent,
                                builder: (context) => BackgroundMusicBrowser(
                                  onMusicSelected: _onBackgroundMusicSelected,
                                  onCancel: () => Navigator.pop(context),
                                ),
                              );
                              HapticFeedback.lightImpact();
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
                  ),
                if (_isControlsVisible)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton.filledTonal(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black45,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_showComments)
          SizedBox(
            height: 400, // Fixed height for comments panel
            child: CommentPanel(
              projectId: widget.mediaAsset.projectId,
              assetId: widget.mediaAsset.id,
              currentTime: controller.value.position,
            ),
          ),
        if (!_showComments)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.mediaAsset.fileName,
                    style: Theme.of(context).textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _cachedDuration ?? '00:00',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        // Audio controls
        if (_isControlsVisible)
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.all(8.0),
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Original video audio
                Row(
                  children: [
                    const Icon(Icons.video_file, size: 20, color: Colors.white),
                    const SizedBox(width: 8),
                    const Text(
                      'Original Audio',
                      style: TextStyle(color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: Colors.white,
                          inactiveTrackColor: Colors.white.withOpacity(0.3),
                          thumbColor: Colors.white,
                          overlayColor: Colors.white.withOpacity(0.1),
                        ),
                        child: Slider(
                          value: _videoVolume,
                          onChanged: _updateVideoVolume,
                        ),
                      ),
                    ),
                  ],
                ),
                // Background music (if selected)
                if (_backgroundMusicUrl != null)
                  Row(
                    children: [
                      const Icon(Icons.music_note,
                          size: 20, color: Colors.white),
                      const SizedBox(width: 8),
                      const Text(
                        'Background Music',
                        style: TextStyle(color: Colors.white),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: Colors.white,
                            inactiveTrackColor: Colors.white.withOpacity(0.3),
                            thumbColor: Colors.white,
                            overlayColor: Colors.white.withOpacity(0.1),
                          ),
                          child: Slider(
                            value: _musicVolume,
                            onChanged: _updateMusicVolume,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return duration.inHours > 0
        ? '$hours:$minutes:$seconds'
        : '$minutes:$seconds';
  }
}

class _OptimizedVideoControls extends StatelessWidget {
  final VideoPlayerController controller;
  final VoidCallback onPlayPause;
  final String position;
  final String duration;
  final Widget child;

  const _OptimizedVideoControls({
    required this.controller,
    required this.onPlayPause,
    required this.position,
    required this.duration,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Use RepaintBoundary for the slider
            RepaintBoundary(
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  child,
                  ValueListenableBuilder(
                    valueListenable: controller,
                    builder: (context, VideoPlayerValue value, child) {
                      return Slider(
                        value: value.position.inMilliseconds.toDouble(),
                        max: value.duration.inMilliseconds.toDouble(),
                        onChanged: (newPosition) {
                          controller.seekTo(
                            Duration(milliseconds: newPosition.toInt()),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    position,
                    style: const TextStyle(color: Colors.white),
                  ),
                  IconButton(
                    icon: Icon(
                      controller.value.isPlaying
                          ? Icons.pause
                          : Icons.play_arrow,
                      color: Colors.white,
                    ),
                    onPressed: onPlayPause,
                  ),
                  Text(
                    duration,
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
