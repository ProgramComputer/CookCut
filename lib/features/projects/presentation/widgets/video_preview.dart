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
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _showTrimming = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    _controller = VideoPlayerController.network(widget.mediaAsset.fileUrl);
    try {
      await _controller.initialize();
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading video: ${e.toString()}')),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTrimComplete(String trimmedVideoUrl) {
    setState(() => _showTrimming = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Video trimmed successfully')),
    );
    // Here you would typically update the MediaBloc with the new trimmed video
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_showTrimming) {
      return VideoTrimWidget(
        mediaAsset: widget.mediaAsset,
        onTrimComplete: _handleTrimComplete,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              VideoPlayer(_controller),
              _VideoControls(
                controller: _controller,
                onPlayPause: () {
                  setState(() {
                    if (_controller.value.isPlaying) {
                      _controller.pause();
                    } else {
                      _controller.play();
                    }
                  });
                },
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton.filledTonal(
                  onPressed: () => setState(() => _showTrimming = true),
                  icon: const Icon(Icons.cut),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black45,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.mediaAsset.fileName,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                _formatDuration(_controller.value.duration),
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

class _VideoControls extends StatelessWidget {
  final VideoPlayerController controller;
  final VoidCallback onPlayPause;

  const _VideoControls({
    required this.controller,
    required this.onPlayPause,
  });

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
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
          ValueListenableBuilder(
            valueListenable: controller,
            builder: (context, VideoPlayerValue value, child) {
              return Slider(
                value: value.position.inMilliseconds.toDouble(),
                max: value.duration.inMilliseconds.toDouble(),
                onChanged: (newPosition) {
                  controller
                      .seekTo(Duration(milliseconds: newPosition.toInt()));
                },
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ValueListenableBuilder(
                  valueListenable: controller,
                  builder: (context, VideoPlayerValue value, child) {
                    return Text(
                      _formatDuration(value.position),
                      style: const TextStyle(color: Colors.white),
                    );
                  },
                ),
                IconButton(
                  icon: Icon(
                    controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                  ),
                  onPressed: onPlayPause,
                ),
                ValueListenableBuilder(
                  valueListenable: controller,
                  builder: (context, VideoPlayerValue value, child) {
                    return Text(
                      _formatDuration(value.duration),
                      style: const TextStyle(color: Colors.white),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
