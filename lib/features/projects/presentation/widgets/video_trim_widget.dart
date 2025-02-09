import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../data/services/openshot_service.dart';
import '../../domain/entities/media_asset.dart';

class VideoTrimWidget extends StatefulWidget {
  final MediaAsset mediaAsset;
  final Function(String) onTrimComplete;

  const VideoTrimWidget({
    super.key,
    required this.mediaAsset,
    required this.onTrimComplete,
  });

  @override
  State<VideoTrimWidget> createState() => _VideoTrimWidgetState();
}

class _VideoTrimWidgetState extends State<VideoTrimWidget>
    with SingleTickerProviderStateMixin {
  late VideoPlayerController _controller;
  final OpenshotService _openshotService = OpenshotService();
  bool _isLoading = false;
  double _startValue = 0.0;
  double _endValue = 1.0;
  Duration? _duration;
  String? _currentProjectId;
  double _exportProgress = 0.0;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation =
        Tween<double>(begin: 0.0, end: 1.0).animate(_fadeController);
    _fadeController.forward();
  }

  Future<void> _initializeVideo() async {
    _controller = VideoPlayerController.network(widget.mediaAsset.fileUrl);
    await _controller.initialize();
    _duration = _controller.value.duration;
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _monitorExportProgress(String projectId) async {
    while (_isLoading && mounted) {
      try {
        final progress = await _openshotService.getExportProgress(projectId);
        if (mounted) {
          setState(() => _exportProgress = progress);
        }
        if (progress >= 1.0) break;
        await Future.delayed(const Duration(seconds: 2));
      } catch (e) {
        print('Error monitoring export progress: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error monitoring progress: $e')),
          );
        }
      }
    }
  }

  Future<void> _handleTrim() async {
    if (_duration == null) return;

    setState(() {
      _isLoading = true;
      _exportProgress = 0.0;
    });

    try {
      final startTime = Duration(
          milliseconds: (_startValue * _duration!.inMilliseconds).round());
      final endTime = Duration(
          milliseconds: (_endValue * _duration!.inMilliseconds).round());

      // Start monitoring progress
      _currentProjectId = 'Trim_${DateTime.now().millisecondsSinceEpoch}';
      _monitorExportProgress(_currentProjectId!);

      final trimmedVideoUrl = await _openshotService.trimVideo(
        videoUrl: widget.mediaAsset.fileUrl,
        startTime: startTime,
        endTime: endTime,
      );

      if (mounted) {
        widget.onTrimComplete(trimmedVideoUrl);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error trimming video: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _exportProgress = 0.0;
          _currentProjectId = null;
        });
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (_duration == null) {
      return const Material(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.black,
      child: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              // Top toolbar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                color: Colors.black,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Cancel trimming',
                      style:
                          IconButton.styleFrom(foregroundColor: Colors.white),
                    ),
                    const Spacer(),
                    if (!_isLoading)
                      FilledButton.icon(
                        onPressed: _handleTrim,
                        icon: const Icon(Icons.check),
                        label: const Text('Apply Trim'),
                        style: FilledButton.styleFrom(
                          backgroundColor: colorScheme.primaryContainer,
                          foregroundColor: colorScheme.onPrimaryContainer,
                        ),
                      ),
                  ],
                ),
              ),

              // Video preview
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        VideoPlayer(_controller),
                        if (_isLoading)
                          Container(
                            color: Colors.black54,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const CircularProgressIndicator(),
                                const SizedBox(height: 16),
                                Text(
                                  'Processing: ${(_exportProgress * 100).toStringAsFixed(1)}%',
                                  style: const TextStyle(color: Colors.white),
                                ),
                                if (_exportProgress > 0 && _exportProgress < 1.0)
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: LinearProgressIndicator(
                                      value: _exportProgress,
                                      backgroundColor: Colors.white24,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // Trimming controls
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.black,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Time indicator
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceVariant.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: Icon(
                              _controller.value.isPlaying
                                  ? Icons.pause
                                  : Icons.play_arrow,
                              color: Colors.white,
                            ),
                            onPressed: _isLoading
                                ? null
                                : () {
                                    setState(() {
                                      _controller.value.isPlaying
                                          ? _controller.pause()
                                          : _controller.play();
                                    });
                                  },
                          ),
                          const SizedBox(width: 16),
                          Text(
                            '${_formatDuration(Duration(milliseconds: (_startValue * _duration!.inMilliseconds).round()))} - ${_formatDuration(Duration(milliseconds: (_endValue * _duration!.inMilliseconds).round()))}',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Trim slider
                    Container(
                      height: 64,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceVariant.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Video thumbnails would go here in a production app
                          RangeSlider(
                            values: RangeValues(_startValue, _endValue),
                            onChanged: _isLoading
                                ? null
                                : (RangeValues values) {
                                    setState(() {
                                      _startValue = values.start;
                                      _endValue = values.end;
                                    });
                                    final position = Duration(
                                      milliseconds: (values.start *
                                              _duration!.inMilliseconds)
                                          .round(),
                                    );
                                    _controller.seekTo(position);
                                  },
                            activeColor: colorScheme.primary,
                            inactiveColor:
                                colorScheme.surfaceVariant.withOpacity(0.3),
                          ),
                        ],
                      ),
                    ),
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
