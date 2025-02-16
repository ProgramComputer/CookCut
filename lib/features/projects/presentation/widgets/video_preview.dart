import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../../domain/entities/media_asset.dart';
import '../../domain/entities/background_music.dart';
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
import 'package:supabase_flutter/supabase_flutter.dart';
import '../bloc/media_bloc.dart';
import '../../data/repositories/media_repository_impl.dart';
import '../../data/services/media_processing_service.dart';
import '../../domain/entities/text_overlay.dart';
import '../../domain/entities/timer_overlay.dart';
import 'video_overlay_renderer.dart';
import 'overlay_toolbar.dart';
import 'text_overlay_editor.dart';
import 'timer_overlay_editor.dart';

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

  // Overlay state
  final List<TextOverlay> _textOverlays = [];
  final List<TimerOverlay> _timerOverlays = [];
  bool _isEditingOverlays = false;
  TextOverlay? _selectedTextOverlay;
  TimerOverlay? _selectedTimerOverlay;

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

  Future<void> _onBackgroundMusicSelected(BackgroundMusic music) async {
    try {
      setState(() {
        _backgroundMusicUrl = music.url;
        _musicVolume = music.volume;
      });
      Navigator.pop(context); // Dismiss the bottom sheet after selection
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

  void _showOverlayOptions() {
    print('[DEBUG] Showing overlay options');
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Add Overlay',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.text_fields),
              title: const Text('Add Text'),
              subtitle: const Text('Add text overlay to your video'),
              onTap: () {
                print('[DEBUG] Text overlay option tapped');
                Navigator.pop(context);
                _addTextOverlay();
              },
            ),
            ListTile(
              leading: const Icon(Icons.timer),
              title: const Text('Add Timer'),
              subtitle: const Text('Add countdown timer to your video'),
              onTap: () {
                print('[DEBUG] Timer overlay option tapped');
                Navigator.pop(context);
                _addTimerOverlay();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _removeSelectedOverlay() {
    setState(() {
      if (_selectedTextOverlay != null) {
        _textOverlays.removeWhere((o) => o.id == _selectedTextOverlay!.id);
        _selectedTextOverlay = null;
      }
      if (_selectedTimerOverlay != null) {
        _timerOverlays.removeWhere((o) => o.id == _selectedTimerOverlay!.id);
        _selectedTimerOverlay = null;
      }
    });
  }

  void _handleTextOverlaySelected(TextOverlay overlay) {
    setState(() {
      _selectedTextOverlay = overlay;
      _selectedTimerOverlay = null;
      _isEditingOverlays = true;
      _isControlsVisible = true;
    });

    // Show text editor
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: TextOverlayEditor(
          overlay: overlay,
          onUpdate: (updated) {
            setState(() {
              final index = _textOverlays.indexWhere((o) => o.id == overlay.id);
              if (index != -1) {
                _textOverlays[index] = updated;
              }
            });
          },
          onDelete: () {
            setState(() {
              _textOverlays.removeWhere((o) => o.id == overlay.id);
              _selectedTextOverlay = null;
            });
            Navigator.pop(context);
          },
          videoWidth: _player!.value.size.width,
          videoHeight: _player!.value.size.height,
        ),
      ),
    );
  }

  void _handleTimerOverlaySelected(TimerOverlay overlay) {
    setState(() {
      _selectedTimerOverlay = overlay;
      _selectedTextOverlay = null;
      _isEditingOverlays = true;
      _isControlsVisible = true;
    });

    // Show timer editor
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: TimerOverlayEditor(
          overlay: overlay,
          onUpdate: (updated) {
            setState(() {
              final index =
                  _timerOverlays.indexWhere((o) => o.id == overlay.id);
              if (index != -1) {
                _timerOverlays[index] = updated;
              }
            });
          },
          onDelete: () {
            setState(() {
              _timerOverlays.removeWhere((o) => o.id == overlay.id);
              _selectedTimerOverlay = null;
            });
            Navigator.pop(context);
          },
          videoWidth: _player!.value.size.width,
          videoHeight: _player!.value.size.height,
        ),
      ),
    );
  }

  void _addTextOverlay() {
    print('[DEBUG] Adding text overlay');
    if (_player == null) {
      print('[DEBUG] Player is null');
      return;
    }

    setState(() {
      final overlay = TextOverlay(
        id: DateTime.now().toString(),
        text: 'New Text',
        startTime: _player!.value.position.inSeconds.toDouble(),
        endTime: _player!.value.position.inSeconds.toDouble() + 5,
        x: 0.5,
        y: 0.5,
        color: '#FFFFFF',
        fontSize: 24.0,
        fontFamily: 'Arial',
        backgroundColor: '#000000',
        backgroundOpacity: 0.5,
        isBold: false,
        isItalic: false,
        alignment: 'center',
        scale: 1.0,
        rotation: 0.0,
      );
      print('[DEBUG] Created text overlay: ${overlay.id}');
      _textOverlays.add(overlay);
      _isEditingOverlays = true;
      _selectedTextOverlay = overlay;
      print('[DEBUG] Text overlays count: ${_textOverlays.length}');
    });
  }

  void _addTimerOverlay() {
    print('[DEBUG] Adding timer overlay');
    if (_player == null) {
      print('[DEBUG] Player is null');
      return;
    }

    setState(() {
      final overlay = TimerOverlay(
        id: DateTime.now().toString(),
        durationSeconds: 60,
        startTime: _player!.value.position.inSeconds.toDouble(),
        x: 0.5,
        y: 0.5,
        color: '#FFFFFF',
        fontSize: 24.0,
        backgroundColor: '#000000',
        backgroundOpacity: 0.5,
        style: 'minimal',
        showMilliseconds: false,
        alignment: 'center',
        scale: 1.0,
      );
      print('[DEBUG] Created timer overlay: ${overlay.id}');
      _timerOverlays.add(overlay);
      _isEditingOverlays = true;
      _selectedTimerOverlay = overlay;
      print('[DEBUG] Timer overlays count: ${_timerOverlays.length}');
    });
  }

  void _handleTextDragEnd(TextOverlay overlay, Offset offset) {
    setState(() {
      final index = _textOverlays.indexWhere((o) => o.id == overlay.id);
      if (index != -1) {
        _textOverlays[index] = overlay.copyWith(
          x: offset.dx / _player!.value.size.width,
          y: offset.dy / _player!.value.size.height,
        );
      }
    });
  }

  void _handleTimerDragEnd(TimerOverlay overlay, Offset offset) {
    setState(() {
      final index = _timerOverlays.indexWhere((o) => o.id == overlay.id);
      if (index != -1) {
        _timerOverlays[index] = overlay.copyWith(
          x: offset.dx / _player!.value.size.width,
          y: offset.dy / _player!.value.size.height,
        );
      }
    });
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
                    VideoOverlayRenderer(
                      textOverlays: _textOverlays,
                      timerOverlays: _timerOverlays,
                      currentTime: _player!.value.position.inSeconds.toDouble(),
                      videoWidth: _player!.value.size.width,
                      videoHeight: _player!.value.size.height,
                      isEditing: _isEditingOverlays,
                      onTextDragEnd: _handleTextDragEnd,
                      onTimerDragEnd: _handleTimerDragEnd,
                      selectedTextOverlay: _selectedTextOverlay,
                      selectedTimerOverlay: _selectedTimerOverlay,
                      onTextSelected: _handleTextOverlaySelected,
                      onTimerSelected: _handleTimerOverlaySelected,
                    ),
                    // Controls overlay
                    if (_isControlsVisible)
                      Stack(
                        children: [
                          // Video controls at bottom
                          Positioned.fill(
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTap: () {
                                // Only toggle controls if we're not editing overlays
                                if (!_isEditingOverlays) {
                                  setState(() {
                                    _isControlsVisible = !_isControlsVisible;
                                  });
                                }
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
                                      _showOverlayOptions();
                                      HapticFeedback.lightImpact();
                                    },
                                    icon: const Icon(Icons.text_fields),
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.black45,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton.filledTonal(
                                    onPressed: () {
                                      print(
                                          '[VideoPreview] Opening BackgroundMusicBrowser');
                                      showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        useSafeArea: true,
                                        constraints: BoxConstraints(
                                          maxHeight: MediaQuery.of(context)
                                                  .size
                                                  .height *
                                              0.9,
                                        ),
                                        builder: (context) {
                                          print(
                                              '[VideoPreview] Building BackgroundMusicBrowser modal');
                                          return SizedBox(
                                            width: double.infinity,
                                            child: BlocProvider(
                                              create: (context) => MediaBloc(
                                                mediaRepository:
                                                    MediaRepositoryImpl(
                                                  firestore: FirebaseFirestore
                                                      .instance,
                                                  supabase:
                                                      Supabase.instance.client,
                                                  auth: FirebaseAuth.instance,
                                                  mediaProcessingService:
                                                      MediaProcessingService(
                                                    supabase: Supabase
                                                        .instance.client,
                                                  ),
                                                ),
                                              ),
                                              child: BackgroundMusicBrowser(
                                                onMusicSelected:
                                                    _onBackgroundMusicSelected,
                                                onCancel: () =>
                                                    Navigator.pop(context),
                                                projectId:
                                                    widget.mediaAsset.projectId,
                                                videoDuration: _player
                                                        ?.value.duration ??
                                                    const Duration(seconds: 0),
                                                onPreviewPositionChanged:
                                                    (position) {
                                                  if (_player != null) {
                                                    _player!.seekTo(position);
                                                  }
                                                },
                                              ),
                                            ),
                                          );
                                        },
                                      ).then((_) {
                                        print(
                                            '[VideoPreview] BackgroundMusicBrowser modal closed');
                                      });
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
                          // Move audio controls next to the close button for better reachability
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Row(
                              children: [
                                if (_backgroundMusicUrl != null)
                                  Container(
                                    width: 100,
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.black45,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      children: [
                                        const SizedBox(width: 8),
                                        const Icon(
                                          Icons.volume_up,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                        Expanded(
                                          child: Slider(
                                            value: _musicVolume,
                                            onChanged: _updateMusicVolume,
                                            activeColor: Colors.white,
                                            inactiveColor: Colors.white24,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                IconButton.filledTonal(
                                  onPressed: () => Navigator.of(context).pop(),
                                  icon: const Icon(Icons.close),
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.black45,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              // Comments Section - Now always visible
              Expanded(
                child: CommentPanel(
                  projectId: widget.mediaAsset.projectId,
                  assetId: widget.mediaAsset.id,
                  currentTime: _player!.value.position,
                ),
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
