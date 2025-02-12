import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

void main() => runApp(const VideoApp());

/// Stateful widget to fetch and then display video content.
class VideoApp extends StatefulWidget {
  const VideoApp({super.key});

  @override
  _VideoAppState createState() => _VideoAppState();
}

class _VideoAppState extends State<VideoApp> {
  late VideoPlayerController _controller;
  bool _isError = false;
  String? _errorMessage;
  Timer? _bufferingDebounce;
  bool _isBuffering = false;

  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
  }

  Future<void> _initializeVideoPlayer() async {
    try {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(
            'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4'),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
          allowBackgroundPlayback: false,
        ),
        httpHeaders: {
          'Connection': 'keep-alive',
          'Accept-Encoding': 'gzip, deflate, br',
          'Accept': '*/*',
        },
      );

      // Add listeners for video state
      _controller.addListener(_videoListener);

      // Initialize with error handling
      await _controller.initialize().then((_) {
        if (mounted) {
          setState(() {
            _logVideoDetails();
          });
        }
      }).catchError((error) {
        _handleError('Error initializing video: $error');
      });

      // Set initial volume and start preloading
      await _controller.setVolume(1.0);
      await _controller.setLooping(true);

      // Preload the first few seconds
      if (mounted) {
        _preloadVideo();
      }
    } catch (e) {
      _handleError('Exception during video player setup: $e');
    }
  }

  void _videoListener() {
    if (!mounted) return;

    final value = _controller.value;

    // Handle buffering state
    if (_bufferingDebounce?.isActive ?? false) {
      _bufferingDebounce!.cancel();
    }
    _bufferingDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _isBuffering = value.isBuffering;
        });
      }
    });

    // Handle errors
    if (value.hasError) {
      _handleError(value.errorDescription ?? 'Unknown playback error');
    }
  }

  void _handleError(String error) {
    if (!mounted) return;

    debugPrint(error);
    setState(() {
      _isError = true;
      _errorMessage = error;
    });
  }

  Future<void> _preloadVideo() async {
    try {
      // Seek to 5 seconds and back to preload initial buffer
      await _controller.seekTo(const Duration(seconds: 5));
      await Future.delayed(const Duration(milliseconds: 100));
      await _controller.seekTo(Duration.zero);
    } catch (e) {
      debugPrint('Error preloading video: $e');
    }
  }

  void _logVideoDetails() {
    debugPrint('Video initialized successfully');
    debugPrint('Video size: ${_controller.value.size}');
    debugPrint('Video duration: ${_controller.value.duration}');
    debugPrint('Video position: ${_controller.value.position}');
    debugPrint('Video buffered: ${_controller.value.buffered}');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Video Demo',
      theme: ThemeData.dark(),
      home: Scaffold(
        body: Center(
          child: _isError
              ? _buildErrorWidget()
              : _controller.value.isInitialized
                  ? _buildVideoPlayer()
                  : const CircularProgressIndicator(),
        ),
        floatingActionButton: _controller.value.isInitialized
            ? FloatingActionButton(
                onPressed: _togglePlayPause,
                child: Icon(
                  _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                ),
              )
            : null,
      ),
    );
  }

  void _togglePlayPause() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
    });
  }

  Widget _buildErrorWidget() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline, color: Colors.red, size: 60),
        const SizedBox(height: 16),
        Text(
          'Error playing video:\n${_errorMessage ?? 'Unknown error'}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.red),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () {
            setState(() {
              _isError = false;
              _errorMessage = null;
            });
            _initializeVideoPlayer();
          },
          child: const Text('Retry'),
        ),
      ],
    );
  }

  Widget _buildVideoPlayer() {
    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: Stack(
        alignment: Alignment.center,
        children: [
          VideoPlayer(_controller),
          if (_isBuffering)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _bufferingDebounce?.cancel();
    _controller.removeListener(_videoListener);
    _controller.dispose();
    super.dispose();
  }
}
