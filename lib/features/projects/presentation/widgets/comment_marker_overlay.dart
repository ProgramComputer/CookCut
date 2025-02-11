import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/video_comment.dart';
import '../bloc/video_comment_bloc.dart';

class CommentMarkerOverlay extends StatelessWidget {
  final Duration videoDuration;
  final Duration currentPosition;
  final Function(Duration) onMarkerTap;

  const CommentMarkerOverlay({
    super.key,
    required this.videoDuration,
    required this.currentPosition,
    required this.onMarkerTap,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VideoCommentBloc, VideoCommentState>(
      builder: (context, state) {
        if (state.comments.isEmpty) {
          return const SizedBox.shrink();
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: state.comments.map((comment) {
                final position = comment.timestamp;
                final progress =
                    position.inMilliseconds / videoDuration.inMilliseconds;
                final xPosition = progress * constraints.maxWidth;

                return Positioned(
                  left: xPosition - 8, // Center the marker
                  child: GestureDetector(
                    onTap: () => onMarkerTap(position),
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }
}
