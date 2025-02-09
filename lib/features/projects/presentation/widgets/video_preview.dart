import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../domain/entities/media_asset.dart';
import 'video_trim_widget.dart';

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
  bool _isInitialized = false;
  bool _showTrimming = false;
  bool _isControlsVisible = true;

  // Cache the video duration to avoid rebuilds
  String? _cachedDuration;
  String? _cachedPosition;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      final controller = VideoPlayerController.network(
        widget.mediaAsset.fileUrl,
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
          allowBackgroundPlayback: false,
        ),
      );
      _controller = controller;

      // Pre-cache next second of video
      await controller.initialize();
      await controller.setPlaybackSpeed(1.0);

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _cachedDuration = _formatDuration(controller.value.duration);
        });

        // Listen to position changes less frequently
        controller.addListener(_updatePosition);
      }
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

  @override
  void dispose() {
    _controller?.removeListener(_updatePosition);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(VideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaAsset.fileUrl != widget.mediaAsset.fileUrl) {
      _isInitialized = false;
      _controller?.removeListener(_updatePosition);
      _controller?.dispose();
      _controller = null;
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
                  _OptimizedVideoControls(
                    controller: controller,
                    onPlayPause: () {
                      setState(() {
                        if (controller.value.isPlaying) {
                          controller.pause();
                        } else {
                          controller.play();
                        }
                      });
                    },
                    position: _cachedPosition ?? '00:00',
                    duration: _cachedDuration ?? '00:00',
                  ),
                if (_isControlsVisible)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: IconButton.filledTonal(
                      onPressed: _showTrimDialog,
                      icon: const Icon(Icons.cut),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black45,
                        foregroundColor: Colors.white,
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

  const _OptimizedVideoControls({
    required this.controller,
    required this.onPlayPause,
    required this.position,
    required this.duration,
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
              child: ValueListenableBuilder(
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
