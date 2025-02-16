import 'package:flutter/material.dart';

class ChatInputField extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onSend;

  const ChatInputField({
    super.key,
    required this.controller,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: Theme.of(context).colorScheme.surfaceVariant,
                ),
                child: TextField(
                  controller: controller,
                  textCapitalization: TextCapitalization.sentences,
                  keyboardType: TextInputType.multiline,
                  maxLines: null,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (text) {
                    if (text.isNotEmpty) {
                      onSend(text);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, child) {
                return AnimatedScale(
                  scale: value.text.isEmpty ? 0.8 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: AnimatedOpacity(
                    opacity: value.text.isEmpty ? 0.5 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: IconButton.filledTonal(
                      onPressed: value.text.isEmpty
                          ? null
                          : () => onSend(value.text),
                      icon: const Icon(Icons.send_rounded),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}