import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/video_comment_bloc.dart';

class CommentToggleButton extends StatelessWidget {
  final bool isOpen;
  final VoidCallback onToggle;

  const CommentToggleButton({
    super.key,
    required this.isOpen,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocBuilder<VideoCommentBloc, VideoCommentState>(
      builder: (context, state) {
        return FilledButton.tonalIcon(
          onPressed: onToggle,
          icon: Badge(
            isLabelVisible: state.comments.isNotEmpty,
            label: Text(state.comments.length.toString()),
            child: Icon(
              isOpen ? Icons.comment : Icons.comment_outlined,
              color: isOpen
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          label: Text(isOpen ? 'Hide Comments' : 'Show Comments'),
          style: FilledButton.styleFrom(
            backgroundColor: isOpen
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surfaceVariant,
            foregroundColor: isOpen
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
        );
      },
    );
  }
}
