import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/video_comment_bloc.dart';
import '../../domain/entities/video_comment.dart';
import 'package:timeago/timeago.dart' as timeago;

class CommentList extends StatelessWidget {
  final String clipId;
  final Duration currentTime;
  final Function(Duration) onTimestampTap;

  const CommentList({
    super.key,
    required this.clipId,
    required this.currentTime,
    required this.onTimestampTap,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VideoCommentBloc, VideoCommentState>(
      builder: (context, state) {
        if (state.status == VideoCommentStatus.loading &&
            state.comments.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state.status == VideoCommentStatus.error) {
          return Center(
            child: Text(
              state.error ?? 'An error occurred',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
          );
        }

        if (state.comments.isEmpty) {
          return Center(
            child: Text(
              'No comments yet',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          );
        }

        final sortedComments = List<VideoComment>.from(state.comments)
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: sortedComments.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) {
            final comment = sortedComments[index];
            return _CommentTile(
              comment: comment,
              currentTime: currentTime,
              onTimestampTap: onTimestampTap,
            );
          },
        );
      },
    );
  }
}

class _CommentTile extends StatelessWidget {
  final VideoComment comment;
  final Duration currentTime;
  final Function(Duration) onTimestampTap;

  const _CommentTile({
    required this.comment,
    required this.currentTime,
    required this.onTimestampTap,
  });

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCurrentTimestamp =
        (currentTime - comment.timestamp).abs() < const Duration(seconds: 1);

    return InkWell(
      onTap: () => onTimestampTap(comment.timestamp),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundImage: comment.authorAvatarUrl.isNotEmpty
                      ? NetworkImage(comment.authorAvatarUrl)
                      : null,
                  child: comment.authorAvatarUrl.isEmpty
                      ? Text(comment.authorName[0].toUpperCase())
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        comment.authorName,
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(
                        timeago.format(comment.createdAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => onTimestampTap(comment.timestamp),
                  icon: Icon(
                    Icons.timer,
                    size: 16,
                    color: isCurrentTimestamp
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                  label: Text(
                    _formatDuration(comment.timestamp),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isCurrentTimestamp
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              comment.text,
              style: theme.textTheme.bodyMedium,
            ),
            if (comment.updatedAt != null) ...[
              const SizedBox(height: 4),
              Text(
                '(edited ${timeago.format(comment.updatedAt!)})',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
