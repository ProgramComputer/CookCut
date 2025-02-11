import 'package:flutter/material.dart';
import '../../domain/entities/video_comment.dart';

class CommentMarker extends StatelessWidget {
  final VideoComment comment;
  final VoidCallback onTap;
  final bool isSelected;

  const CommentMarker({
    super.key,
    required this.comment,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.secondary,
          border: Border.all(
            color: theme.colorScheme.surface,
            width: 2,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: theme.colorScheme.primary.withOpacity(0.4),
                blurRadius: 4,
                spreadRadius: 1,
              ),
          ],
        ),
      ),
    );
  }
}
