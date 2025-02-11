import 'package:flutter/material.dart';
import '../../domain/entities/timer_overlay.dart';

class TimerOverlayEditor extends StatefulWidget {
  final TimerOverlay overlay;
  final Function(TimerOverlay) onUpdate;
  final VoidCallback onDelete;
  final double videoWidth;
  final double videoHeight;

  const TimerOverlayEditor({
    Key? key,
    required this.overlay,
    required this.onUpdate,
    required this.onDelete,
    required this.videoWidth,
    required this.videoHeight,
  }) : super(key: key);

  @override
  State<TimerOverlayEditor> createState() => _TimerOverlayEditorState();
}

class _TimerOverlayEditorState extends State<TimerOverlayEditor> {
  late TextEditingController _labelController;
  late TimerOverlay _currentOverlay;

  @override
  void initState() {
    super.initState();
    _currentOverlay = widget.overlay;
    _labelController = TextEditingController(text: widget.overlay.label);
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  void _updateOverlay(TimerOverlay updated) {
    setState(() => _currentOverlay = updated);
    widget.onUpdate(updated);
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
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
                    controller: _labelController,
                    decoration: const InputDecoration(
                      labelText: 'Timer Label (Optional)',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      _updateOverlay(_currentOverlay.copyWith(label: value));
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
            Text(
                'Duration: ${_formatDuration(_currentOverlay.durationSeconds)}',
                style: theme.textTheme.titleMedium),
            Slider(
              value: _currentOverlay.durationSeconds.toDouble(),
              min: 1,
              max: 3600, // 1 hour max
              divisions: 3600,
              label: _formatDuration(_currentOverlay.durationSeconds),
              onChanged: (value) {
                _updateOverlay(
                    _currentOverlay.copyWith(durationSeconds: value.toInt()));
              },
            ),
            const SizedBox(height: 16),
            Text('Start Time', style: theme.textTheme.bodySmall),
            Slider(
              value: _currentOverlay.startTime,
              min: 0,
              max: 100, // This should be video duration
              onChanged: (value) {
                _updateOverlay(_currentOverlay.copyWith(startTime: value));
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Timer Style',
                      border: OutlineInputBorder(),
                    ),
                    value: _currentOverlay.style,
                    items: const [
                      DropdownMenuItem(
                        value: 'minimal',
                        child: Text('Minimal'),
                      ),
                      DropdownMenuItem(
                        value: 'standard',
                        child: Text('Standard'),
                      ),
                      DropdownMenuItem(
                        value: 'detailed',
                        child: Text('Detailed'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        _updateOverlay(_currentOverlay.copyWith(style: value));
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Switch(
                  value: _currentOverlay.showMilliseconds,
                  onChanged: (value) {
                    _updateOverlay(
                        _currentOverlay.copyWith(showMilliseconds: value));
                  },
                ),
                const Text('Show Milliseconds'),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.color_lens),
                    label: const Text('Timer Color'),
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
