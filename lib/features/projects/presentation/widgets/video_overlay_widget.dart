import 'package:flutter/material.dart';
import '../../domain/entities/video_overlay_model.dart';

class VideoOverlayWidget extends StatelessWidget {
  final List<VideoOverlayModel> overlays;
  final Duration currentTime;
  final double videoWidth;
  final double videoHeight;
  final bool isEditing;
  final Function(TextOverlayModel, Offset)? onTextDragEnd;
  final Function(TimerOverlayModel, Offset)? onTimerDragEnd;

  const VideoOverlayWidget({
    Key? key,
    required this.overlays,
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
      children: overlays.map((overlay) {
        final isVisible = currentTime.inMilliseconds >= overlay.startTime;
        if (!isVisible && !isEditing) return const SizedBox.shrink();

        if (overlay is TextOverlayModel) {
          final isEndTimeReached =
              currentTime.inMilliseconds >= overlay.endTime;
          if (isEndTimeReached && !isEditing) return const SizedBox.shrink();

          return Positioned(
            left: overlay.position.dx,
            top: overlay.position.dy,
            child: isEditing
                ? Draggable(
                    feedback: _buildTextOverlay(overlay),
                    childWhenDragging: const SizedBox.shrink(),
                    onDragEnd: (details) {
                      final RenderBox box =
                          context.findRenderObject() as RenderBox;
                      final localPosition = box.globalToLocal(details.offset);
                      onTextDragEnd?.call(overlay, localPosition);
                    },
                    child: _buildTextOverlay(overlay),
                  )
                : _buildTextOverlay(overlay),
          );
        } else if (overlay is TimerOverlayModel) {
          return Positioned(
            left: overlay.position.dx,
            top: overlay.position.dy,
            child: isEditing
                ? Draggable(
                    feedback: _buildTimerOverlay(overlay),
                    childWhenDragging: const SizedBox.shrink(),
                    onDragEnd: (details) {
                      final RenderBox box =
                          context.findRenderObject() as RenderBox;
                      final localPosition = box.globalToLocal(details.offset);
                      onTimerDragEnd?.call(overlay, localPosition);
                    },
                    child: _buildTimerOverlay(overlay),
                  )
                : _buildTimerOverlay(overlay),
          );
        }

        return const SizedBox.shrink();
      }).toList(),
    );
  }

  Widget _buildTextOverlay(TextOverlayModel overlay) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: isEditing ? Colors.black26 : null,
        border: isEditing ? Border.all(color: Colors.white, width: 1) : null,
      ),
      child: Text(
        overlay.text,
        style: TextStyle(
          color: Color(
              int.parse(overlay.color.substring(1, 7), radix: 16) + 0xFF000000),
          fontSize: overlay.fontSize,
        ),
      ),
    );
  }

  Widget _buildTimerOverlay(TimerOverlayModel overlay) {
    final elapsedSeconds = (currentTime.inMilliseconds / 1000).floor();
    final remainingSeconds = overlay.durationSeconds - elapsedSeconds;
    final displaySeconds = remainingSeconds.clamp(0, overlay.durationSeconds);

    final minutes = (displaySeconds / 60).floor();
    final seconds = displaySeconds % 60;

    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: isEditing ? Colors.black26 : null,
        border: isEditing ? Border.all(color: Colors.white, width: 1) : null,
      ),
      child: Text(
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
        style: TextStyle(
          color: Color(
              int.parse(overlay.color.substring(1, 7), radix: 16) + 0xFF000000),
          fontSize: overlay.fontSize,
        ),
      ),
    );
  }
}
