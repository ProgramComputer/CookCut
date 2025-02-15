import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../data/services/ffmpeg_service.dart';
import '../../domain/entities/media_asset.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:isolate';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  final FFmpegService _ffmpegService = FFmpegService();
  bool _isLoading = false;
  double _startValue = 0.0;
  double _endValue = 1.0;
  Duration? _duration;
  String? _currentJobId;
  double _exportProgress = 0.0;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  Timer? _seekTimer;
  Timer? _progressTimer;

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

  void _cleanup() {
    _progressTimer?.cancel();
    setState(() {
      _isLoading = false;
      _exportProgress = 0.0;
    });
    _currentJobId = null;
  }

  Future<void> _monitorExportProgress(String jobId) async {
    _progressTimer?.cancel();

    try {
      print('Starting progress monitoring for job $jobId');

      // Create a receive port for communication
      final receivePort = ReceivePort();

      // Create a completer to handle completion
      final completer = Completer<void>();

      // Listen for messages from the isolate
      receivePort.listen((dynamic message) async {
        print('Received message from isolate: $message');

        if (message is Map<String, dynamic>) {
          if (mounted) {
            final currentStatus = message['status'] as String? ?? 'unknown';
            print('Processing status update: $currentStatus');

            switch (currentStatus) {
              case 'starting':
                setState(() {
                  _exportProgress = 0.0;
                });
                break;
              case 'downloading':
                final downloadProgress = message['downloadProgress'] as num?;
                setState(() {
                  _exportProgress =
                      (downloadProgress?.toDouble() ?? 0.0).clamp(0.0, 100.0) /
                          100.0;
                });
                break;
              case 'processing':
                final progress = message['progress'] as num?;
                setState(() {
                  final normalizedProgress =
                      (progress?.toDouble() ?? 0.0).clamp(0.0, 100.0) / 100.0;
                  _exportProgress = normalizedProgress;
                });
                break;
              case 'complete':
                setState(() {
                  _exportProgress = 1.0;
                });
                final outputUrl = message['url'] as String?;
                if (outputUrl != null) {
                  try {
                    // Update the MediaAsset in Firestore
                    await FirebaseFirestore.instance
                        .collection('projects')
                        .doc(widget.mediaAsset.projectId)
                        .collection('media_assets')
                        .doc(widget.mediaAsset.id)
                        .update({
                      'fileUrl': outputUrl,
                      'updatedAt': FieldValue.serverTimestamp(),
                      'status': 'ready',
                    });

                    widget.onTrimComplete(outputUrl);
                    if (mounted) {
                      Navigator.of(context).pop();
                    }
                  } catch (e) {
                    print('Error updating MediaAsset: $e');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content:
                              Text('Error updating video: ${e.toString()}'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
                completer.complete();
                break;
              case 'failed':
                final error =
                    message['error'] as String? ?? 'Processing failed';
                print('Processing failed: $error');
                completer.completeError(Exception(error));
                break;
            }
          }
        } else if (message is String && message == 'done') {
          print('Isolate signaled completion');
          receivePort.close();
        }
      });

      print('Spawning monitoring isolate');
      // Spawn the isolate
      final isolate = await Isolate.spawn(
        _monitorProgressIsolate,
        _IsolateMessage(
          jobId: jobId,
          sendPort: receivePort.sendPort,
          supabaseUrl: dotenv.get('SUPABASE_URL'),
          supabaseKey: dotenv.get('SUPABASE_ANON_KEY'),
        ),
      );

      // Wait for completion or error
      try {
        await completer.future;
      } finally {
        print('Cleaning up isolate');
        isolate.kill();
        receivePort.close();
      }
    } catch (e, stack) {
      print('Error in progress monitoring: $e');
      print('Stack trace: $stack');
      _cleanup();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().contains('failed')
                ? e.toString()
                : 'Lost connection to processing server'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _handleTrim,
            ),
          ),
        );
      }
    }
  }

  // Static method to run in isolate
  static Future<void> _monitorProgressIsolate(_IsolateMessage message) async {
    final supabase = SupabaseClient(
      message.supabaseUrl,
      message.supabaseKey,
    );
    StreamSubscription? subscription;

    try {
      print('Starting Supabase job monitoring for job ${message.jobId}');

      // Create a stream subscription to watch the job
      subscription = supabase
          .from('video_jobs')
          .stream(primaryKey: ['id'])
          .eq('id', message.jobId)
          .listen((List<Map<String, dynamic>> jobs) {
            if (jobs.isEmpty) {
              print('No job data received');
              return;
            }

            final job = jobs.first;
            print(
                'Received job update: ${job['status']} - Progress: ${job['progress']}%');

            // Send status update to main isolate
            message.sendPort.send({
              'status': job['status'],
              'progress': job['progress'],
              'url': job['output_url'],
              'error': job['error']
            });

            // If job is complete or failed, close the subscription
            if (job['status'] == 'complete' || job['status'] == 'failed') {
              print(
                  'Job ${message.jobId} finished with status: ${job['status']}');
              subscription?.cancel();
              message.sendPort.send('done');
            }
          }, onError: (error) {
            print('Supabase subscription error: $error');
            message.sendPort.send(
                {'status': 'failed', 'error': 'Monitoring error: $error'});
            subscription?.cancel();
            message.sendPort.send('done');
          });

      // Keep the isolate alive until explicitly closed
      await Future.delayed(const Duration(hours: 1));
    } catch (e, stack) {
      print('Error in Supabase monitoring: $e');
      print('Stack trace: $stack');
      message.sendPort
          .send({'status': 'failed', 'error': 'Monitoring error: $e'});
    } finally {
      subscription?.cancel();
    }
  }

  Future<void> _handleTrim() async {
    if (_duration == null) return;

    int retryCount = 0;
    const maxRetries = 3;

    while (retryCount < maxRetries) {
      try {
        setState(() {
          _isLoading = true;
          _exportProgress = 0.0;
        });

        final startTime = Duration(
            milliseconds: (_startValue * _duration!.inMilliseconds).round());
        final endTime = Duration(
            milliseconds: (_endValue * _duration!.inMilliseconds).round());

        // Validate trim points
        if (endTime <= startTime) {
          throw Exception('End time must be after start time');
        }

        if (endTime - startTime < const Duration(seconds: 1)) {
          throw Exception('Clip must be at least 1 second long');
        }

        print('Starting video trim: ${widget.mediaAsset.fileUrl}');
        print('Attempt ${retryCount + 1} of $maxRetries');

        final result = await _ffmpegService
            .trimVideo(
              videoUrl: widget.mediaAsset.fileUrl,
              startTime: startTime,
              endTime: endTime,
              projectId: widget.mediaAsset.projectId,
              position: widget.mediaAsset.position,
              layer: widget.mediaAsset.layer ?? 0,
            )
            .timeout(
              const Duration(minutes: 5),
              onTimeout: () => throw TimeoutException(
                  'Processing timed out after 5 minutes'),
            );

        print('Trim result: $result');
        _currentJobId = result['jobId'];

        if (mounted) {
          _monitorExportProgress(_currentJobId!);

          // Show progress started message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Downloading video for processing...'),
                ],
              ),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 2),
            ),
          );
        }
        break; // Success, exit retry loop
      } catch (e, stackTrace) {
        retryCount++;
        print('Error during trim (attempt $retryCount): $e');
        print('Stack trace: $stackTrace');

        if (retryCount >= maxRetries || e.toString().contains('must be')) {
          _cleanup();
          if (mounted) {
            String errorMessage = 'Error trimming video';
            if (e is TimeoutException) {
              errorMessage =
                  'Processing timed out. Please try with a shorter clip.';
            } else if (e.toString().contains('Connection closed')) {
              errorMessage =
                  'Lost connection to server. Please check your internet and try again.';
            } else {
              errorMessage = 'Error: ${e.toString()}';
            }

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
                action: SnackBarAction(
                  label: retryCount < maxRetries ? 'Retry' : 'Close',
                  textColor: Colors.white,
                  onPressed: retryCount < maxRetries ? _handleTrim : () {},
                ),
              ),
            );
          }
          break;
        }

        // Wait before retry
        await Future.delayed(Duration(seconds: retryCount * 2));
      }
    }
  }

  @override
  void dispose() {
    _cleanup();
    _controller.dispose();
    _fadeController.dispose();
    _seekTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  void _debouncedSeek(Duration position) {
    _seekTimer?.cancel();
    _seekTimer = Timer(const Duration(milliseconds: 50), () {
      _controller.seekTo(position);
    });
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
                                // Custom animated progress indicator
                                SizedBox(
                                  width: 120,
                                  height: 120,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      CircularProgressIndicator(
                                        value: _exportProgress,
                                        strokeWidth: 8,
                                        backgroundColor: Colors.white24,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          _exportProgress >= 1.0
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .tertiary
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                        ),
                                      ),
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (_exportProgress >= 1.0)
                                            Icon(
                                              Icons
                                                  .check_circle_outline_rounded,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .tertiary,
                                              size: 48,
                                            )
                                          else
                                            Text(
                                              _exportProgress == 0
                                                  ? 'Preparing'
                                                  : _exportProgress < 0.02
                                                      ? 'Starting'
                                                      : 'Processing',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium
                                                  ?.copyWith(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                            ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _exportProgress >= 1.0
                                                ? 'Complete'
                                                : _exportProgress == 0
                                                    ? 'Uploading video...'
                                                    : _exportProgress < 0.02
                                                        ? 'Starting process...'
                                                        : 'Processing video...',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: _exportProgress >= 1.0
                                                      ? Theme.of(context)
                                                          .colorScheme
                                                          .tertiary
                                                      : Colors.white70,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                // Progress bar with percentage
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 32.0),
                                  child: Column(
                                    children: [
                                      if (_exportProgress > 0)
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              '${(_exportProgress * 100).toStringAsFixed(0)}%',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleSmall
                                                  ?.copyWith(
                                                    color: Colors.white70,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      const SizedBox(height: 8),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: LinearProgressIndicator(
                                          value: _exportProgress > 0
                                              ? _exportProgress
                                              : null,
                                          minHeight: 8,
                                          backgroundColor: Colors.white12,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            Theme.of(context)
                                                .colorScheme
                                                .primary,
                                          ),
                                        ),
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
                    _TrimSlider(
                      startValue: _startValue,
                      endValue: _endValue,
                      isLoading: _isLoading,
                      duration: _duration!,
                      colorScheme: colorScheme,
                      onChanged: (RangeValues values) {
                        setState(() {
                          _startValue = values.start;
                          _endValue = values.end;
                        });

                        final position = Duration(
                          milliseconds:
                              (values.start * _duration!.inMilliseconds)
                                  .round(),
                        );
                        _debouncedSeek(position);
                      },
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

class _TrimSlider extends StatelessWidget {
  final double startValue;
  final double endValue;
  final bool isLoading;
  final Duration duration;
  final ValueChanged<RangeValues> onChanged;
  final ColorScheme colorScheme;

  const _TrimSlider({
    required this.startValue,
    required this.endValue,
    required this.isLoading,
    required this.duration,
    required this.onChanged,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          RangeSlider(
            values: RangeValues(startValue, endValue),
            onChanged: isLoading ? null : onChanged,
            activeColor: colorScheme.primary,
            inactiveColor: colorScheme.surfaceVariant.withOpacity(0.3),
          ),
        ],
      ),
    );
  }
}

// Message class for isolate communication
class _IsolateMessage {
  final String jobId;
  final SendPort sendPort;
  final String supabaseUrl;
  final String supabaseKey;

  const _IsolateMessage({
    required this.jobId,
    required this.sendPort,
    required this.supabaseUrl,
    required this.supabaseKey,
  });
}
