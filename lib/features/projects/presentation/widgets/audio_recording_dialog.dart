import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:permission_handler/permission_handler.dart';
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
  RecorderController? _recorderController;

  @override
  void initState() {
    super.initState();
    _initializeRecorder();
  }

  Future<void> _initializeRecorder() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission is required to record audio'),
          ),
        );
      }
      return;
    }

    _recorderController = RecorderController()
      ..androidEncoder = AndroidEncoder.aac
      ..androidOutputFormat = AndroidOutputFormat.mpeg4
      ..iosEncoder = IosEncoder.kAudioFormatMPEG4AAC
      ..sampleRate = 44100;
  }

  void _startRecording() async {
    try {
      _recordingPath = await _audioProcessingService.startVoiceOverRecording();
      if (_recordingPath != null) {
        await _recorderController?.record(
          path: _recordingPath,
          androidEncoder: AndroidEncoder.aac,
          androidOutputFormat: AndroidOutputFormat.mpeg4,
          iosEncoder: IosEncoder.kAudioFormatMPEG4AAC,
          sampleRate: 44100,
        );
        setState(() {
          _isRecording = true;
          _recordingDuration = Duration.zero;
        });
        _startDurationTimer();
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
      await _recorderController?.pause();
      setState(() {
        _isPaused = true;
      });
      _durationTimer?.cancel();
    }
  }

  void _resumeRecording() async {
    if (_isPaused) {
      await _recorderController?.record();
      setState(() {
        _isPaused = false;
      });
      _startDurationTimer();
    }
  }

  void _stopRecording() async {
    try {
      final path = await _recorderController?.stop();
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
    _recorderController?.dispose();
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
              AudioWaveforms(
                enableGesture: true,
                size: Size(MediaQuery.of(context).size.width * 0.7, 50),
                recorderController: _recorderController!,
                waveStyle: const WaveStyle(
                  waveColor: Colors.blue,
                  extendWaveform: true,
                  showMiddleLine: false,
                ),
                padding: const EdgeInsets.only(left: 18),
                margin: const EdgeInsets.symmetric(horizontal: 15),
              ),
              const SizedBox(height: 16),
              Text(
                _formatDuration(_recordingDuration),
                style: const TextStyle(fontSize: 24),
              ),
            ],
            const SizedBox(height: 16),
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
