import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
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
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
  VideoPlayerController? _player;
  bool _isInitialized = false;
  bool _showTrimming = false;
  bool _isControlsVisible = true;
  bool _showComments = false;
  bool _isAnalyzing = false;
  bool _isTrimming = false;
  double _trimStart = 0.0;
  double _trimEnd = 1.0;

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
    print("[DEBUG] initState: _showComments initialized to $_showComments");
  }

  Future<void> _initializeAudio() async {
    // Audio initialization can remain the same
  }

  Future<void> _initializeVideo() async {
    try {
      // Clean up existing player first
      if (_player != null) {
        await _player!.pause();
        _player!.removeListener(_updatePosition);
        await Future.delayed(const Duration(milliseconds: 500));
        await _player!.dispose();
        _player = null;
      }

      // Create and initialize new player with platform-specific options
      final newPlayer = VideoPlayerController.network(
        widget.mediaAsset.fileUrl,
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
          allowBackgroundPlayback: false,
        ),
      );

      await newPlayer.initialize();
      newPlayer.addListener(_updatePosition);

      if (!mounted) {
        await newPlayer.dispose();
        return;
      }

      setState(() {
        _player = newPlayer;
        _isInitialized = true;
        _cachedDuration = _formatDuration(newPlayer.value.duration);
      });

      await newPlayer.setVolume(_videoVolume);
      await newPlayer.play();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading video: ${e.toString()}')),
        );
      }
    }
  }

  void _updatePosition() {
    if (!mounted || _player == null) return;
    final newPosition = _formatDuration(_player!.value.position);
    final duration = _formatDuration(_player!.value.duration);

    if (newPosition != _cachedPosition || duration != _cachedDuration) {
      setState(() {
        _cachedPosition = newPosition;
        _cachedDuration = duration;
      });
    }
  }

  void _updateVideoVolume(double value) {
    setState(() {
      _videoVolume = value;
      if (_player != null) {
        _player!.setVolume(value);
      }
    });
  }

  void _updateMusicVolume(double value) {
    setState(() {
      _musicVolume = value;
      // _musicPlayer?.setVolume(value * 100);
    });
  }

  Future<void> _onBackgroundMusicSelected(String url) async {
    try {
      // await _musicPlayer?.stop();
      // await _musicPlayer?.open(Media(url));
      // await _musicPlayer?.setVolume(_musicVolume * 100);
      // await _musicPlayer?.play();
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
    if (_player != null) {
      _player!.pause();
      _player!.removeListener(_updatePosition);
      Future.delayed(const Duration(milliseconds: 500), () {
        try {
          _player!.dispose();
        } catch (e) {
          debugPrint('Error disposing video controller: $e');
        }
      });
    }
    // _musicPlayer?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(VideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaAsset.fileUrl != widget.mediaAsset.fileUrl) {
      _isInitialized = false;
      // _musicPlayer?.stop();
      _backgroundMusicUrl = null;
      _initializeVideo();
    }
  }

  void _showTrimDialog() {
    // Pause the current video before showing trim dialog
    if (_player?.value.isPlaying == true) {
      _player!.pause();
    }

    showDialog(
      context: context,
      useSafeArea: false,
      barrierDismissible: false,
      builder: (context) => VideoTrimWidget(
        mediaAsset: widget.mediaAsset,
        onTrimComplete: (String trimmedVideoUrl) {
          Navigator.of(context).pop();
          // Resume playing the original video
          _player!.play();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Video trimmed successfully')),
          );
        },
      ),
    );
  }

  void _toggleComments() {
    print("[DEBUG] _toggleComments called, current state: $_showComments");
    setState(() {
      _showComments = !_showComments;
      print("[DEBUG] _toggleComments new state: $_showComments");
    });
  }

  void _seekToComment(Duration position) {
    if (_player != null) {
      _player!.seekTo(position);
    }
  }

  Future<void> _analyzeRecipe() async {
    if (_isAnalyzing) {
      print('Recipe analysis already in progress, skipping...');
      return;
    }

    print('Starting recipe analysis...');
    setState(() {
      _isAnalyzing = true;
    });

    try {
      final ffmpegServer = dotenv.env['AWS_EC2_FFMPEG'];
      final ffmpegApiKey = dotenv.env['FFMPEG_API_KEY'];

      print('FFMPEG Server: $ffmpegServer');

      if (ffmpegServer == null || ffmpegServer.isEmpty) {
        throw Exception('AWS_EC2_FFMPEG environment variable is not set');
      }

      if (ffmpegApiKey == null || ffmpegApiKey.isEmpty) {
        throw Exception('FFMPEG_API_KEY environment variable is not set');
      }

      final ffmpegServerUrl = 'http://$ffmpegServer';
      print('Constructed FFMPEG Server URL: $ffmpegServerUrl');

      print('Showing analysis in progress snackbar...');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 16),
              Text('Analyzing recipe...'),
            ],
          ),
          duration: Duration(seconds: 10),
        ),
      );

      final response = await http.post(
        Uri.parse('$ffmpegServerUrl/analyze-recipe'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': ffmpegApiKey,
        },
        body: jsonEncode({
          'videoPath': widget.mediaAsset.fileUrl,
          'projectId': widget.mediaAsset.projectId,
        }),
      );

      print('Recipe analysis API response status: ${response.statusCode}');
      if (!mounted) {
        print('Widget not mounted after API call, aborting...');
        return;
      }

      if (response.statusCode == 200) {
        print('Recipe analysis successful, parsing results...');
        final result = jsonDecode(response.body);

        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Recipe Analysis'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    result['recipe']['title'] ?? 'Recipe',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Ingredients:',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  ...List<Widget>.from(
                    (result['recipe']['ingredients'] as List).map(
                      (ingredient) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.check_circle_outline),
                        title: Text(ingredient['item']),
                        subtitle: Text(
                            '${ingredient['amount']} ${ingredient['unit']}'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Steps:',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  ...List<Widget>.from(
                    (result['recipe']['steps'] as List).map(
                      (step) => ListTile(
                        dense: true,
                        leading: Text('${step['number']}.'),
                        title: Text(step['instruction']),
                        subtitle: step['tip'] != null
                            ? Text('Tip: ${step['tip']}')
                            : null,
                        onTap: () {
                          if (step['timestamp'] != null) {
                            _player
                                ?.seekTo(Duration(seconds: step['timestamp']));
                            Navigator.pop(context);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      } else {
        print('Recipe analysis failed with status: ${response.statusCode}');
        throw Exception('Failed to analyze recipe');
      }
    } catch (e) {
      print('Error during recipe analysis: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error analyzing recipe: ${e.toString()}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      print('Recipe analysis completed, cleaning up...');
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
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

  String _formatDurationFromRatio(double ratio) {
    final duration = _player?.value.duration;
    if (duration == null) return '00:00';

    final position = Duration(
      milliseconds: (ratio * duration.inMilliseconds).round(),
    );
    return _formatDuration(position);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _player == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Loading video...',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      );
    }

    return BlocProvider(
      create: (context) => VideoCommentBloc(
        commentRepository: VideoCommentRepositoryImpl(
          firestore: FirebaseFirestore.instance,
          auth: FirebaseAuth.instance,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              AspectRatio(
                aspectRatio: _player!.value.aspectRatio,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    VideoPlayer(_player!),
                    // Controls overlay
                    if (_isControlsVisible)
                      Stack(
                        children: [
                          // Video controls at bottom
                          Positioned.fill(
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTap: () {
                                setState(() {
                                  _isControlsVisible = !_isControlsVisible;
                                });
                              },
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Spacer(),
                                  _OptimizedVideoControls(
                                    player: _player!,
                                    onPlayPause: () {
                                      setState(() {
                                        if (_player!.value.isPlaying) {
                                          _player!.pause();
                                        } else {
                                          _player!.play();
                                        }
                                      });
                                    },
                                    position: _cachedPosition ?? '00:00',
                                    duration: _cachedDuration ?? '00:00',
                                    child: Slider(
                                      value: _player!
                                              .value.position.inMilliseconds
                                              .toDouble() /
                                          _player!.value.duration.inMilliseconds
                                              .toDouble(),
                                      min: 0.0,
                                      max: 1.0,
                                      onChanged: (newPosition) {
                                        final newPositionInMilliseconds =
                                            (newPosition *
                                                    _player!.value.duration
                                                        .inMilliseconds)
                                                .round();
                                        _player!.seekTo(Duration(
                                            milliseconds:
                                                newPositionInMilliseconds));
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Top gradient overlay
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            height: 64,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withOpacity(0.7),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Top controls - Now at the very top of the stack
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Material(
                              type: MaterialType.transparency,
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
                                      final currentPosition =
                                          _player!.value.position;
                                      context.read<VideoCommentBloc>().add(
                                            AddComment(
                                              projectId:
                                                  widget.mediaAsset.projectId,
                                              assetId: widget.mediaAsset.id,
                                              timestamp: currentPosition,
                                              text: '',
                                            ),
                                          );
                                      if (!_showComments) {
                                        _toggleComments();
                                      }
                                      HapticFeedback.lightImpact();
                                    },
                                    icon: const Icon(Icons.edit),
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.black45,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton.filledTonal(
                                    onPressed: () {
                                      _analyzeRecipe();
                                      HapticFeedback.lightImpact();
                                    },
                                    icon: const Icon(Icons.restaurant_menu),
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.black45,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
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
                  ],
                ),
              ),
              // Comments or Info Section
              Expanded(
                child: _showComments
                    ? CommentPanel(
                        projectId: widget.mediaAsset.projectId,
                        assetId: widget.mediaAsset.id,
                        currentTime: _player!.value.position,
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptimizedVideoControls extends StatelessWidget {
  final VideoPlayerController player;
  final VoidCallback onPlayPause;
  final String position;
  final String duration;
  final Widget child;

  const _OptimizedVideoControls({
    required this.player,
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
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ValueListenableBuilder(
              valueListenable: player,
              builder: (context, value, child) {
                return SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 12,
                    ),
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.white.withOpacity(0.3),
                    thumbColor: Colors.white,
                    overlayColor: Colors.white.withOpacity(0.1),
                  ),
                  child: Slider(
                    value: value.position.inMilliseconds.toDouble() /
                        value.duration.inMilliseconds.toDouble(),
                    min: 0.0,
                    max: 1.0,
                    onChanged: (newPosition) {
                      player.seekTo(Duration(
                        milliseconds:
                            (newPosition * value.duration.inMilliseconds)
                                .round(),
                      ));
                    },
                  ),
                );
              },
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
                      player.value.isPlaying ? Icons.pause : Icons.play_arrow,
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
