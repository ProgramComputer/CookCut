import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:math' as math;

class AudioWaveform extends StatefulWidget {
  final String url;
  final Duration position;
  final Function(Duration position) onPositionChanged;
  final Duration startTime;
  final Duration endTime;

  const AudioWaveform({
    Key? key,
    required this.url,
    required this.position,
    required this.onPositionChanged,
    required this.startTime,
    required this.endTime,
  }) : super(key: key);

  @override
  State<AudioWaveform> createState() => _AudioWaveformState();
}

class _AudioWaveformState extends State<AudioWaveform> {
  final _audioPlayer = AudioPlayer();
  List<double> _waveformData = [];
  bool _isLoading = true;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadAudio();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadAudio() async {
    try {
      setState(() => _isLoading = true);

      // Load audio file
      await _audioPlayer.setUrl(widget.url);
      _duration = _audioPlayer.duration ?? Duration.zero;

      // Generate waveform data (simplified version)
      // In a real app, you'd want to analyze the actual audio data
      final random = math.Random(42); // Fixed seed for consistent visualization
      _waveformData = List.generate(100, (index) => random.nextDouble());

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading audio for waveform: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        final box = context.findRenderObject() as RenderBox;
        final position = details.localPosition;
        final percent = position.dx / box.size.width;
        final newPosition = Duration(
          milliseconds: (_duration.inMilliseconds * percent).toInt(),
        );
        widget.onPositionChanged(newPosition);
      },
      child: CustomPaint(
        size: Size.infinite,
        painter: WaveformPainter(
          waveformData: _waveformData,
          position: widget.position,
          duration: _duration,
          startTime: widget.startTime,
          endTime: widget.endTime,
          primaryColor: Theme.of(context).colorScheme.primary,
          secondaryColor:
              Theme.of(context).colorScheme.primary.withOpacity(0.3),
        ),
      ),
    );
  }
}

class WaveformPainter extends CustomPainter {
  final List<double> waveformData;
  final Duration position;
  final Duration duration;
  final Duration startTime;
  final Duration endTime;
  final Color primaryColor;
  final Color secondaryColor;

  WaveformPainter({
    required this.waveformData,
    required this.position,
    required this.duration,
    required this.startTime,
    required this.endTime,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (waveformData.isEmpty || duration == Duration.zero) return;

    final paint = Paint()
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final barWidth = size.width / waveformData.length;
    final heightScale = size.height / 2;
    final centerY = size.height / 2;

    // Draw selection range
    if (startTime != Duration.zero || endTime != duration) {
      final startX =
          (startTime.inMilliseconds / duration.inMilliseconds) * size.width;
      final endX =
          (endTime.inMilliseconds / duration.inMilliseconds) * size.width;

      final selectionPaint = Paint()
        ..color = primaryColor.withOpacity(0.1)
        ..style = PaintingStyle.fill;

      canvas.drawRect(
        Rect.fromLTRB(startX, 0, endX, size.height),
        selectionPaint,
      );
    }

    // Draw waveform bars
    for (var i = 0; i < waveformData.length; i++) {
      final x = i * barWidth;
      final barHeight = waveformData[i] * heightScale;

      // Determine if this bar is before or after the current position
      final isBeforePosition =
          x < (position.inMilliseconds / duration.inMilliseconds) * size.width;
      paint.color = isBeforePosition ? primaryColor : secondaryColor;

      canvas.drawLine(
        Offset(x, centerY - barHeight),
        Offset(x, centerY + barHeight),
        paint,
      );
    }

    // Draw position indicator
    final positionX =
        (position.inMilliseconds / duration.inMilliseconds) * size.width;
    final positionPaint = Paint()
      ..color = primaryColor
      ..strokeWidth = 2;

    canvas.drawLine(
      Offset(positionX, 0),
      Offset(positionX, size.height),
      positionPaint,
    );
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    return position != oldDelegate.position ||
        startTime != oldDelegate.startTime ||
        endTime != oldDelegate.endTime;
  }
}
