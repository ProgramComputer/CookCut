import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import '../../domain/entities/media_asset.dart';

class AudioPreview extends StatefulWidget {
  final MediaAsset mediaAsset;

  const AudioPreview({
    super.key,
    required this.mediaAsset,
  });

  @override
  State<AudioPreview> createState() => _AudioPreviewState();
}

class _AudioPreviewState extends State<AudioPreview> {
  late final Player _player;
  bool _isPlaying = false;
  bool _isInitialized = false;
  double _playbackSpeed = 1.0;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      await _player.open(Media(widget.mediaAsset.fileUrl));
      // Wait for the duration to be available
      final duration = await _player.stream.duration.first;
      if (mounted) {
        setState(() {
          _duration = duration;
          _isInitialized = true;
        });
      }

      // Listen to position changes
      _player.stream.position.listen((position) {
        if (mounted) {
          setState(() {
            // Ensure position never exceeds duration
            if (position > _duration) {
              _position = _duration;
            } else {
              _position = position;
            }
          });
        }
      });

      // Listen to playback state changes
      _player.stream.playing.listen((playing) {
        if (mounted) {
          setState(() => _isPlaying = playing);
        }
      });

      // Set initial playback rate
      await _player.setRate(_playbackSpeed);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading audio: $e')),
        );
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Future<void> _onPlayPause() async {
    if (!_isInitialized) return;

    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> _onSeek(double value) async {
    if (!_isInitialized) return;

    // Calculate the target position based on the normalized value
    final targetPosition = Duration(
      milliseconds: (value * _duration.inMilliseconds).round(),
    );
    await _player.seek(targetPosition);
  }

  Future<void> _onSpeedChange(double? speed) async {
    if (speed != null && _isInitialized) {
      setState(() => _playbackSpeed = speed);
      await _player.setRate(speed);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(16),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Audio Preview',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (!_isInitialized)
              const CircularProgressIndicator()
            else
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                        onPressed: _onPlayPause,
                      ),
                      const SizedBox(width: 20),
                      DropdownButton<double>(
                        value: _playbackSpeed,
                        items: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((speed) {
                          return DropdownMenuItem(
                            value: speed,
                            child: Text('${speed}x'),
                          );
                        }).toList(),
                        onChanged: _onSpeedChange,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_formatDuration(_position)),
                        Text(_formatDuration(_duration)),
                      ],
                    ),
                  ),
                  Slider(
                    value: _duration.inMilliseconds > 0
                        ? (_position.inMilliseconds / _duration.inMilliseconds)
                            .clamp(0.0, 1.0)
                        : 0.0,
                    max: 1.0,
                    onChanged: _onSeek,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
