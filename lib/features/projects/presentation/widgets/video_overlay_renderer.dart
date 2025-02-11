import 'package:flutter/material.dart';
import '../../domain/entities/text_overlay.dart';
import '../../domain/entities/timer_overlay.dart';

class VideoOverlayRenderer extends StatelessWidget {
  final List<TextOverlay> textOverlays;
  final List<TimerOverlay> timerOverlays;
  final double currentTime;
  final double videoWidth;
  final double videoHeight;
  final bool isEditing;
  final Function(TextOverlay, Offset)? onTextDragEnd;
  final Function(TimerOverlay, Offset)? onTimerDragEnd;

  const VideoOverlayRenderer({
    Key? key,
    required this.textOverlays,
    required this.timerOverlays,
    required this.currentTime,
    required this.videoWidth,
    required this.videoHeight,
    this.isEditing = false,
    this.onTextDragEnd,
    this.onTimerDragEnd,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ...textOverlays
            .where((overlay) =>
                currentTime >= overlay.startTime &&
                currentTime <= overlay.endTime)
            .map((overlay) => _buildTextOverlay(overlay)),
        ...timerOverlays
            .where((overlay) =>
                currentTime >= overlay.startTime &&
                currentTime <= overlay.endTime)
            .map((overlay) => _buildTimerOverlay(overlay)),
      ],
    );
  }

  Widget _buildTextOverlay(TextOverlay overlay) {
    return Positioned(
      left: overlay.x * videoWidth,
      top: overlay.y * videoHeight,
      child: isEditing
          ? Builder(
              builder: (context) => Draggable<TextOverlay>(
                feedback: _TextOverlayWidget(overlay: overlay),
                childWhenDragging: Opacity(
                  opacity: 0.3,
                  child: _TextOverlayWidget(overlay: overlay),
                ),
                child: _TextOverlayWidget(overlay: overlay),
                onDragEnd: (details) {
                  if (onTextDragEnd != null) {
                    final RenderBox box = context.findRenderObject() as RenderBox;
                    final localPosition = box.globalToLocal(details.offset);
                    onTextDragEnd!(
                      overlay,
                      Offset(
                        localPosition.dx / videoWidth,
                        localPosition.dy / videoHeight,
                      ),
                    );
                  }
                },
              ),
            )
          : _TextOverlayWidget(overlay: overlay),
    );
  }

  Widget _buildTimerOverlay(TimerOverlay overlay) {
    final remainingSeconds =
        (overlay.durationSeconds - (currentTime - overlay.startTime))
            .ceil()
            .clamp(0, overlay.durationSeconds);

    return Positioned(
      left: overlay.x * videoWidth,
      top: overlay.y * videoHeight,
      child: isEditing
          ? Builder(
              builder: (context) => Draggable<TimerOverlay>(
                feedback: _TimerOverlayWidget(
                  overlay: overlay,
                  remainingSeconds: remainingSeconds,
                ),
                childWhenDragging: Opacity(
                  opacity: 0.3,
                  child: _TimerOverlayWidget(
                    overlay: overlay,
                    remainingSeconds: remainingSeconds,
                  ),
                ),
                child: _TimerOverlayWidget(
                  overlay: overlay,
                  remainingSeconds: remainingSeconds,
                ),
                onDragEnd: (details) {
                  if (onTimerDragEnd != null) {
                    final RenderBox box = context.findRenderObject() as RenderBox;
                    final localPosition = box.globalToLocal(details.offset);
                    onTimerDragEnd!(
                      overlay,
                      Offset(
                        localPosition.dx / videoWidth,
                        localPosition.dy / videoHeight,
                      ),
                    );
                  }
                },
              ),
            )
          : _TimerOverlayWidget(
              overlay: overlay,
              remainingSeconds: remainingSeconds,
            ),
    );
  }
}

class _TextOverlayWidget extends StatelessWidget {
  final TextOverlay overlay;

  const _TextOverlayWidget({
    super.key,
    required this.overlay,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: overlay.scale,
      child: Transform.rotate(
        angle: overlay.rotation,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 8.0,
            vertical: 4.0,
          ),
          decoration: BoxDecoration(
            color: Color(
              int.parse(overlay.backgroundColor.substring(1), radix: 16) +
                  (overlay.backgroundOpacity * 255).toInt(),
            ),
            borderRadius: BorderRadius.circular(4.0),
          ),
          child: Text(
            overlay.text,
            style: TextStyle(
              color: Color(
                int.parse(overlay.color.substring(1), radix: 16),
              ),
              fontSize: overlay.fontSize,
              fontFamily: overlay.fontFamily,
              fontWeight: overlay.isBold ? FontWeight.bold : FontWeight.normal,
              fontStyle: overlay.isItalic ? FontStyle.italic : FontStyle.normal,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _TimerOverlayWidget extends StatelessWidget {
  final TimerOverlay overlay;
  final int remainingSeconds;

  const _TimerOverlayWidget({
    super.key,
    required this.overlay,
    required this.remainingSeconds,
  });

  String _formatTime() {
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    final secondsStr = seconds.toString().padLeft(2, '0');

    switch (overlay.style) {
      case 'minimal':
        return '$minutes:$secondsStr';
      case 'detailed':
        return '${overlay.label ?? 'Timer'}: $minutes:$secondsStr';
      case 'standard':
      default:
        return '$minutes:$secondsStr';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: overlay.scale,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 12.0,
          vertical: 6.0,
        ),
        decoration: BoxDecoration(
          color: Color(
            int.parse(overlay.backgroundColor.substring(1), radix: 16) +
                (overlay.backgroundOpacity * 255).toInt(),
          ),
          borderRadius: BorderRadius.circular(6.0),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (overlay.label != null && overlay.style == 'detailed')
              Text(
                overlay.label!,
                style: TextStyle(
                  color: Color(
                    int.parse(overlay.color.substring(1), radix: 16),
                  ),
                  fontSize: 14.0,
                ),
              ),
            Text(
              _formatTime(),
              style: TextStyle(
                color: Color(
                  int.parse(overlay.color.substring(1), radix: 16),
                ),
                fontSize: overlay.style == 'minimal' ? 20.0 : 24.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
