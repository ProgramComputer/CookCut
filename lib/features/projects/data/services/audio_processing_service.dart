import 'dart:async';
import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/audio_processing_config.dart';

enum AudioProcessingType {
  import,
  trim,
  mix,
  voiceOver,
  noiseReduction,
  normalize,
  fade
}

class AudioTrack {
  final String path;
  final double volume;
  final Duration startTime;
  final Duration? endTime;
  final Duration fadeInDuration;
  final Duration fadeOutDuration;

  AudioTrack({
    required this.path,
    this.volume = 1.0,
    this.startTime = Duration.zero,
    this.endTime,
    this.fadeInDuration = Duration.zero,
    this.fadeOutDuration = Duration.zero,
  });

  AudioTrack copyWith({
    String? path,
    double? volume,
    Duration? startTime,
    Duration? endTime,
    Duration? fadeInDuration,
    Duration? fadeOutDuration,
  }) {
    return AudioTrack(
      path: path ?? this.path,
      volume: volume ?? this.volume,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      fadeInDuration: fadeInDuration ?? this.fadeInDuration,
      fadeOutDuration: fadeOutDuration ?? this.fadeOutDuration,
    );
  }
}

class ProcessingTask {
  final AudioProcessingType type;
  final String inputPath;
  final Completer<bool> completer;
  final AudioProcessingConfig? config;
  final StreamController<double>? progressController;
  final Map<String, dynamic>? additionalParams;

  ProcessingTask({
    required this.type,
    required this.inputPath,
    required this.completer,
    this.config,
    this.progressController,
    this.additionalParams,
  });
}

class AudioProcessingService {
  final SupabaseClient _supabase;
  final _processingQueue = StreamController<ProcessingTask>.broadcast();
  final _audioPlayer = AudioPlayer();
  final _recorder = AudioRecorder();
  RecorderController? _recorderController;
  PlayerController? _playerController;
  final Map<String, AudioTrack> _audioTracks = {};

  AudioProcessingService({SupabaseClient? supabase})
      : _supabase = supabase ?? Supabase.instance.client {
    _initializeQueue();
    _initializeAudioSession();
  }

  Future<void> _initializeAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
      avAudioSessionCategoryOptions:
          AVAudioSessionCategoryOptions.allowBluetooth,
      avAudioSessionMode: AVAudioSessionMode.spokenAudio,
      avAudioSessionRouteSharingPolicy:
          AVAudioSessionRouteSharingPolicy.defaultPolicy,
      avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.speech,
        flags: AndroidAudioFlags.none,
        usage: AndroidAudioUsage.voiceCommunication,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
      androidWillPauseWhenDucked: true,
    ));
  }

  void _initializeQueue() {
    _processingQueue.stream.listen((task) async {
      try {
        switch (task.type) {
          case AudioProcessingType.import:
            await _importAudio(task);
            break;
          case AudioProcessingType.trim:
            await _trimAudio(task);
            break;
          case AudioProcessingType.mix:
            await _mixAudio(task);
            break;
          case AudioProcessingType.voiceOver:
            await _recordVoiceOver(task);
            break;
          case AudioProcessingType.noiseReduction:
            await _reduceNoise(task);
            break;
          case AudioProcessingType.normalize:
            await _normalizeAudio(task);
            break;
          case AudioProcessingType.fade:
            await _applyFade(task);
            break;
        }
        task.completer.complete(true);
      } catch (e) {
        print('Error processing audio task: $e');
        task.completer.completeError(e);
      }
    });
  }

  Future<String?> importAudio(String audioPath) async {
    try {
      final file = File(audioPath);
      if (!await file.exists()) {
        throw Exception('Audio file not found: $audioPath');
      }

      final mimeType = lookupMimeType(audioPath);
      if (mimeType == null || !mimeType.startsWith('audio/')) {
        throw Exception('Invalid audio file format');
      }

      final completer = Completer<bool>();
      final task = ProcessingTask(
        type: AudioProcessingType.import,
        inputPath: audioPath,
        completer: completer,
      );

      _processingQueue.add(task);
      await completer.future;

      return await _getProcessedAudioUrl(audioPath);
    } catch (e) {
      print('Error importing audio: $e');
      return null;
    }
  }

  Future<void> _importAudio(ProcessingTask task) async {
    final file = File(task.inputPath);
    final fileName =
        'audio_${DateTime.now().millisecondsSinceEpoch}${path.extension(task.inputPath)}';
    final storagePath = 'audio/$fileName';

    await _supabase.storage.from('cookcut-media').upload(
          storagePath,
          file,
          fileOptions: FileOptions(contentType: lookupMimeType(task.inputPath)),
        );
  }

  Future<void> addAudioTrack(String trackId, AudioTrack track) async {
    _audioTracks[trackId] = track;
  }

  Future<void> updateAudioTrack(String trackId, AudioTrack track) async {
    if (!_audioTracks.containsKey(trackId)) {
      throw Exception('Track not found: $trackId');
    }
    _audioTracks[trackId] = track;
  }

  Future<void> removeAudioTrack(String trackId) async {
    _audioTracks.remove(trackId);
  }

  Future<void> _mixAudio(ProcessingTask task) async {
    final tracks = task.additionalParams!['tracks'] as List<AudioTrack>;

    // Validate audio download permissions and format for Jamendo tracks
    for (final track in tracks) {
      if (track.path.contains('jamendo.com')) {
        final trackId = _extractJamendoTrackId(track.path);
        final response = await _supabase.functions.invoke(
          'check-jamendo-track',
          body: {
            'trackId': trackId,
            'format': 'mp32', // Use high quality format for mixing
          },
        );

        if (response.status != 200) {
          throw Exception(
              'Failed to validate Jamendo track: ${response.data['message']}');
        }

        final data = response.data as Map<String, dynamic>;
        if (data['audiodownload_allowed'] != true) {
          throw Exception('Audio download not allowed for track: $trackId');
        }

        // Update track path to use the correct audio format URL
        final audioUrl = data['audiodownload'] as String;
        if (audioUrl.isEmpty) {
          throw Exception(
              'Audio download URL not available for track: $trackId');
        }
      }
    }

    // Call OpenShot API for audio mixing with validated tracks
    final response = await _supabase.functions.invoke(
      'mix-audio',
      body: {
        'tracks': tracks
            .map((track) => {
                  'path': track.path,
                  'volume': track.volume,
                  'startTime': track.startTime.inMilliseconds,
                  'endTime': track.endTime?.inMilliseconds,
                  'fadeIn': track.fadeInDuration.inMilliseconds,
                  'fadeOut': track.fadeOutDuration.inMilliseconds,
                })
            .toList(),
      },
    );

    if (response.status != 200) {
      throw Exception('Failed to mix audio: ${response.data['message']}');
    }
  }

  String _extractJamendoTrackId(String url) {
    final uri = Uri.parse(url);
    final trackId = uri.queryParameters['trackid'] ??
        uri.pathSegments.lastWhere(
          (segment) => int.tryParse(segment) != null,
          orElse: () => '',
        );
    if (trackId.isEmpty) {
      throw Exception('Invalid Jamendo track URL: $url');
    }
    return trackId;
  }

  Future<void> _applyFade(ProcessingTask task) async {
    final fadeIn = task.additionalParams!['fadeIn'] as Duration;
    final fadeOut = task.additionalParams!['fadeOut'] as Duration;

    // Validate if the audio is from Jamendo before applying fade
    if (task.inputPath.contains('jamendo.com')) {
      final trackId = _extractJamendoTrackId(task.inputPath);
      final response = await _supabase.functions.invoke(
        'check-jamendo-track',
        body: {
          'trackId': trackId,
          'format': 'mp32',
        },
      );

      if (response.status != 200 ||
          response.data['audiodownload_allowed'] != true ||
          (response.data['audiodownload'] as String).isEmpty) {
        throw Exception(
            'Cannot apply fade: Jamendo track not available or download not allowed');
      }
    }

    final response = await _supabase.functions.invoke(
      'apply-fade',
      body: {
        'audioPath': task.inputPath,
        'fadeInDuration': fadeIn.inMilliseconds,
        'fadeOutDuration': fadeOut.inMilliseconds,
      },
    );

    if (response.status != 200) {
      throw Exception('Failed to apply fade: ${response.data['message']}');
    }
  }

  Future<void> _trimAudio(ProcessingTask task) async {
    final start = Duration(milliseconds: task.additionalParams!['start']);
    final end = Duration(milliseconds: task.additionalParams!['end']);

    final response = await _supabase.functions.invoke(
      'trim-audio',
      body: {
        'audioPath': task.inputPath,
        'startTime': start.inSeconds,
        'endTime': end.inSeconds,
      },
    );

    if (response.status != 200) {
      throw Exception('Failed to trim audio: ${response.data['message']}');
    }
  }

  Future<String?> startVoiceOverRecording() async {
    try {
      if (!await _recorder.hasPermission) {
        throw Exception('Microphone permission not granted');
      }

      final directory = await getTemporaryDirectory();
      final filePath =
          '${directory.path}/voiceover_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: filePath,
      );

      return filePath;
    } catch (e) {
      print('Error starting voice-over recording: $e');
      return null;
    }
  }

  Future<void> stopVoiceOverRecording() async {
    try {
      await _recorder.stop();
    } catch (e) {
      print('Error stopping voice-over recording: $e');
    }
  }

  Future<void> _recordVoiceOver(ProcessingTask task) async {
    // Implementation handled by startVoiceOverRecording and stopVoiceOverRecording
    task.completer.complete(true);
  }

  Future<void> _reduceNoise(ProcessingTask task) async {
    final response = await _supabase.functions.invoke(
      'reduce-noise',
      body: {
        'audioPath': task.inputPath,
        'strength': task.config?.noiseReductionStrength ?? 0.5,
      },
    );

    if (response.status != 200) {
      throw Exception('Failed to reduce noise: ${response.data['message']}');
    }
  }

  Future<void> _normalizeAudio(ProcessingTask task) async {
    final response = await _supabase.functions.invoke(
      'normalize-audio',
      body: {
        'audioPath': task.inputPath,
        'targetDb': task.config?.targetDecibels ?? -23,
      },
    );

    if (response.status != 200) {
      throw Exception('Failed to normalize audio: ${response.data['message']}');
    }
  }

  Future<String?> _getProcessedAudioUrl(String originalPath) async {
    try {
      final fileName = 'processed_${path.basename(originalPath)}';
      final storagePath = 'processed/audio/$fileName';
      return _supabase.storage.from('cookcut-media').getPublicUrl(storagePath);
    } catch (e) {
      print('Error getting processed audio URL: $e');
      return null;
    }
  }

  Future<List<int>> generateWaveform(String audioPath) async {
    try {
      _playerController?.dispose();
      _playerController = PlayerController();

      final file = File(audioPath);
      if (!await file.exists()) {
        throw Exception('Audio file not found');
      }

      await _playerController!.preparePlayer(
        path: audioPath,
        noOfSamples: 100,
        waveForms: true,
      );

      final waveformData = await _playerController!.extractWaveformData();
      // Convert double values to integers by scaling
      return waveformData.map((value) => (value * 100).toInt()).toList();
    } catch (e) {
      print('Error generating waveform: $e');
      return [];
    }
  }

  void dispose() {
    _processingQueue.close();
    _audioPlayer.dispose();
    _recorder.dispose();
    _recorderController?.dispose();
    _playerController?.dispose();
  }
}
