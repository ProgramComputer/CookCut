import 'package:flutter/material.dart';
import '../../domain/entities/text_overlay.dart';

class TextOverlayEditor extends StatefulWidget {
  final TextOverlay overlay;
  final Function(TextOverlay) onUpdate;
  final VoidCallback onDelete;
  final double videoWidth;
  final double videoHeight;

  const TextOverlayEditor({
    Key? key,
    required this.overlay,
    required this.onUpdate,
    required this.onDelete,
    required this.videoWidth,
    required this.videoHeight,
  }) : super(key: key);

  @override
  State<TextOverlayEditor> createState() => _TextOverlayEditorState();
}

class _TextOverlayEditorState extends State<TextOverlayEditor> {
  late TextEditingController _textController;
  late TextOverlay _currentOverlay;

  @override
  void initState() {
    super.initState();
    _currentOverlay = widget.overlay;
    _textController = TextEditingController(text: widget.overlay.text);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _updateOverlay(TextOverlay updated) {
    setState(() => _currentOverlay = updated);
    widget.onUpdate(updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      labelText: 'Text',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      _updateOverlay(_currentOverlay.copyWith(text: value));
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: widget.onDelete,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Start Time', style: theme.textTheme.bodySmall),
                      Slider(
                        value: _currentOverlay.startTime,
                        min: 0,
                        max: _currentOverlay.endTime,
                        onChanged: (value) {
                          _updateOverlay(
                              _currentOverlay.copyWith(startTime: value));
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('End Time', style: theme.textTheme.bodySmall),
                      Slider(
                        value: _currentOverlay.endTime,
                        min: _currentOverlay.startTime,
                        max: 100, // This should be video duration
                        onChanged: (value) {
                          _updateOverlay(
                              _currentOverlay.copyWith(endTime: value));
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Font Size', style: theme.textTheme.bodySmall),
                      Slider(
                        value: _currentOverlay.fontSize,
                        min: 12,
                        max: 72,
                        onChanged: (value) {
                          _updateOverlay(
                              _currentOverlay.copyWith(fontSize: value));
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                ToggleButtons(
                  isSelected: [
                    _currentOverlay.isBold,
                    _currentOverlay.isItalic
                  ],
                  onPressed: (index) {
                    if (index == 0) {
                      _updateOverlay(_currentOverlay.copyWith(
                          isBold: !_currentOverlay.isBold));
                    } else {
                      _updateOverlay(_currentOverlay.copyWith(
                          isItalic: !_currentOverlay.isItalic));
                    }
                  },
                  children: const [
                    Icon(Icons.format_bold),
                    Icon(Icons.format_italic),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.color_lens),
                    label: const Text('Text Color'),
                    onPressed: () {
                      // Show color picker
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.format_color_fill),
                    label: const Text('Background'),
                    onPressed: () {
                      // Show background color picker
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
