import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import '../../../../core/utils/permission_manager.dart';
import '../../data/services/audio_processing_service.dart';

class AudioRecordingDialog extends StatefulWidget {
  final Function(String filePath) onRecordingComplete;

  const AudioRecordingDialog({
    super.key,
    required this.onRecordingComplete,
  });

  @override
  State<AudioRecordingDialog> createState() => _AudioRecordingDialogState();
}

class _AudioRecordingDialogState extends State<AudioRecordingDialog> {
  bool _isRecording = false;
  bool _isPaused = false;
  String? _recordingPath;
  Duration _recordingDuration = Duration.zero;
  Timer? _durationTimer;
  final _audioProcessingService = AudioProcessingService();

  @override
  void initState() {
    super.initState();
    _initializeRecorder();
  }

  Future<void> _initializeRecorder() async {
    final hasPermission = await PermissionManager.requestMicrophonePermission();
    if (!hasPermission) {
      if (!mounted) return;

      if (kIsWeb) {
        // For web, show a simpler dialog as we can't open settings
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Please allow microphone access in your browser to record audio.'),
            duration: Duration(seconds: 5),
          ),
        );
        Navigator.of(context).pop();
        return;
      }

      final bool shouldOpenSettings = await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Microphone Permission Required'),
              content: const Text(
                'This app needs microphone access to record audio. '
                'Please grant microphone permission in app settings.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Open Settings'),
                ),
              ],
            ),
          ) ??
          false;

      if (shouldOpenSettings) {
        await PermissionManager.openAppSettings();
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }
  }

  void _startRecording() async {
    try {
      // Double-check permission before starting recording
      if (!await PermissionManager.checkMicrophonePermission()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission is required to record audio'),
          ),
        );
        return;
      }

      _recordingPath = await _audioProcessingService.startVoiceOverRecording();
      if (_recordingPath != null) {
        setState(() {
          _isRecording = true;
          _recordingDuration = Duration.zero;
        });
        _startDurationTimer();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to start recording. Please try again.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting recording: $e')),
        );
      }
    }
  }

  void _pauseRecording() async {
    if (_isRecording) {
      await _audioProcessingService.stopVoiceOverRecording();
      setState(() {
        _isPaused = true;
      });
      _durationTimer?.cancel();
    }
  }

  void _resumeRecording() async {
    if (_isPaused) {
      _recordingPath = await _audioProcessingService.startVoiceOverRecording();
      if (_recordingPath != null) {
        setState(() {
          _isPaused = false;
        });
        _startDurationTimer();
      }
    }
  }

  void _stopRecording() async {
    try {
      await _audioProcessingService.stopVoiceOverRecording();
      _durationTimer?.cancel();
      if (_recordingPath != null) {
        widget.onRecordingComplete(_recordingPath!);
      }
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error stopping recording: $e')),
        );
      }
    }
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _recordingDuration += const Duration(seconds: 1);
      });
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _audioProcessingService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Record Audio',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_isRecording) ...[
              Container(
                width: MediaQuery.of(context).size.width * 0.7,
                height: 50,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    _formatDuration(_recordingDuration),
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (!_isRecording)
                  FloatingActionButton(
                    onPressed: _startRecording,
                    backgroundColor: Colors.red,
                    child: const Icon(Icons.fiber_manual_record),
                  )
                else ...[
                  if (_isPaused)
                    FloatingActionButton(
                      onPressed: _resumeRecording,
                      child: const Icon(Icons.play_arrow),
                    )
                  else
                    FloatingActionButton(
                      onPressed: _pauseRecording,
                      child: const Icon(Icons.pause),
                    ),
                  FloatingActionButton(
                    onPressed: _stopRecording,
                    child: const Icon(Icons.stop),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
