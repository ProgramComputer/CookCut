import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/video_comment_bloc.dart';
import '../../domain/entities/video_comment.dart';
import 'package:timeago/timeago.dart' as timeago;

class CommentPanel extends StatefulWidget {
  final String projectId;
  final String assetId;
  final Duration currentTime;

  const CommentPanel({
    super.key,
    required this.projectId,
    required this.assetId,
    required this.currentTime,
  });

  @override
  State<CommentPanel> createState() => _CommentPanelState();
}

class _CommentPanelState extends State<CommentPanel> {
  final _commentController = TextEditingController();
  bool _isComposing = false;

  @override
  void initState() {
    super.initState();
    context.read<VideoCommentBloc>().add(
          StartWatchingComments(
            projectId: widget.projectId,
            assetId: widget.assetId,
          ),
        );
  }

  @override
  void dispose() {
    _commentController.dispose();
    context.read<VideoCommentBloc>().add(StopWatchingComments());
    super.dispose();
  }

  void _handleSubmitted(String text) {
    if (text.isEmpty) return;

    context.read<VideoCommentBloc>().add(
          AddComment(
            projectId: widget.projectId,
            assetId: widget.assetId,
            text: text,
            timestamp: widget.currentTime,
          ),
        );

    _commentController.clear();
    setState(() {
      _isComposing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 350,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          left: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'Comments',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(width: 8),
                BlocBuilder<VideoCommentBloc, VideoCommentState>(
                  builder: (context, state) {
                    return Text(
                      '(${state.comments.length})',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Comment List
          Expanded(
            child: BlocBuilder<VideoCommentBloc, VideoCommentState>(
              builder: (context, state) {
                if (state.status == VideoCommentStatus.loading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state.status == VideoCommentStatus.error) {
                  return Center(
                    child: Text(
                      'Error loading comments: ${state.error}',
                      style: TextStyle(
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
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  );
                }

                final sortedComments = List<VideoComment>.from(state.comments)
                  ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: sortedComments.length,
                  itemBuilder: (context, index) {
                    final comment = sortedComments[index];
                    return _CommentTile(
                      comment: comment,
                      onDelete: () {
                        context.read<VideoCommentBloc>().add(
                              DeleteComment(comment.id),
                            );
                      },
                    );
                  },
                );
              },
            ),
          ),

          // Comment Input
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      onChanged: (text) {
                        setState(() {
                          _isComposing = text.isNotEmpty;
                        });
                      },
                      onSubmitted: _handleSubmitted,
                      decoration: InputDecoration(
                        hintText: 'Add a comment...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _isComposing
                        ? () => _handleSubmitted(_commentController.text)
                        : null,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final VideoComment comment;
  final VoidCallback onDelete;

  const _CommentTile({
    required this.comment,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundImage: comment.authorAvatarUrl != null
                      ? NetworkImage(comment.authorAvatarUrl!)
                      : null,
                  child: comment.authorAvatarUrl == null
                      ? Text(comment.authorName[0].toUpperCase())
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        comment.authorName,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        timeago.format(comment.createdAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        comment.text,
                        style: Theme.of(context).textTheme.bodyMedium,
                        softWrap: true,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (context) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.delete),
                              title: const Text('Delete'),
                              onTap: () {
                                Navigator.pop(context);
                                onDelete();
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                // This will be handled by the marker tap
              },
              icon: const Icon(Icons.schedule, size: 16),
              label: Text(_formatDuration(comment.timestamp)),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}
