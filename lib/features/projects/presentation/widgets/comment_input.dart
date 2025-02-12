import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/video_comment_bloc.dart';

class CommentInput extends StatefulWidget {
  final String projectId;
  final String clipId;
  final Duration currentTime;

  const CommentInput({
    super.key,
    required this.projectId,
    required this.clipId,
    required this.currentTime,
  });

  @override
  State<CommentInput> createState() => _CommentInputState();
}

class _CommentInputState extends State<CommentInput> {
  final _textController = TextEditingController();
  bool _isComposing = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _handleSubmitted(String text) {
    if (text.isEmpty) return;

    context.read<VideoCommentBloc>().add(
          AddComment(
            projectId: widget.projectId,
            assetId: widget.clipId,
            text: text,
            timestamp: widget.currentTime,
          ),
        );

    _textController.clear();
    setState(() {
      _isComposing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxHeight: 120,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 100,
                  ),
                  child: TextField(
                    controller: _textController,
                    onChanged: (text) {
                      setState(() {
                        _isComposing = text.isNotEmpty;
                      });
                    },
                    onSubmitted: _handleSubmitted,
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.surfaceVariant,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      isDense: true,
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: null,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _isComposing
                    ? () => _handleSubmitted(_textController.text)
                    : null,
                icon: const Icon(Icons.send),
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
