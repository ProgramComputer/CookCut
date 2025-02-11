import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/text_overlay.dart';
import '../../domain/entities/timer_overlay.dart';

class OverlayToolbar extends StatelessWidget {
  final Function(TextOverlay) onAddText;
  final Function(TimerOverlay) onAddTimer;
  final double videoWidth;
  final double videoHeight;

  const OverlayToolbar({
    Key? key,
    required this.onAddText,
    required this.onAddTimer,
    required this.videoWidth,
    required this.videoHeight,
  }) : super(key: key);

  void _addNewText() {
    final overlay = TextOverlay(
      id: const Uuid().v4(),
      text: 'New Text',
      startTime: 0,
      endTime: 5,
      x: 0.5,
      y: 0.5,
    );
    onAddText(overlay);
  }

  void _addNewTimer() {
    final overlay = TimerOverlay(
      id: const Uuid().v4(),
      durationSeconds: 60,
      startTime: 0,
      x: 0.5,
      y: 0.5,
    );
    onAddTimer(overlay);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Category tabs
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: theme.dividerColor,
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _CategoryTab(
                  icon: Icons.text_fields,
                  label: 'Text',
                  isSelected: true,
                ),
                _CategoryTab(
                  icon: Icons.timer,
                  label: 'Timer',
                ),
                _CategoryTab(
                  icon: Icons.style,
                  label: 'Effects',
                ),
              ],
            ),
          ),
          // Text presets
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick Styles',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _TextPreset(
                        label: 'Title',
                        onTap: () => _addStyledText('Title', 32),
                      ),
                      _TextPreset(
                        label: 'Subtitle',
                        onTap: () => _addStyledText('Subtitle', 24),
                      ),
                      _TextPreset(
                        label: 'Step',
                        onTap: () => _addStyledText('Step 1', 28),
                      ),
                      _TextPreset(
                        label: 'Ingredient',
                        onTap: () => _addStyledText('Ingredient', 20),
                      ),
                      _TextPreset(
                        label: 'Note',
                        onTap: () => _addStyledText('Note', 18),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Timer Presets',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _TimerPreset(
                        label: '30s',
                        onTap: () => _addPresetTimer(30, 'Quick Timer'),
                      ),
                      _TimerPreset(
                        label: '1m',
                        onTap: () => _addPresetTimer(60, 'Cook Timer'),
                      ),
                      _TimerPreset(
                        label: '5m',
                        onTap: () => _addPresetTimer(300, 'Cooking'),
                      ),
                      _TimerPreset(
                        label: '10m',
                        onTap: () => _addPresetTimer(600, 'Baking'),
                      ),
                      _TimerPreset(
                        label: 'Custom',
                        onTap: _addNewTimer,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _addStyledText(String defaultText, double fontSize) {
    final overlay = TextOverlay(
      id: const Uuid().v4(),
      text: defaultText,
      startTime: 0,
      endTime: 5,
      x: 0.5,
      y: 0.5,
      fontSize: fontSize,
    );
    onAddText(overlay);
  }

  void _addPresetTimer(int seconds, String label) {
    final overlay = TimerOverlay(
      id: const Uuid().v4(),
      durationSeconds: seconds,
      startTime: 0,
      x: 0.5,
      y: 0.5,
      label: label,
    );
    onAddTimer(overlay);
  }
}

class _CategoryTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;

  const _CategoryTab({
    Key? key,
    required this.icon,
    required this.label,
    this.isSelected = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withOpacity(0.6),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _TextPreset extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TextPreset({
    Key? key,
    required this.label,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

class _TimerPreset extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TimerPreset({
    Key? key,
    required this.label,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.timer, size: 16),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}
