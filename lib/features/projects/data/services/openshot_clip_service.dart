import 'dart:convert';
import 'package:http/http.dart' as http;

class OpenShotClipService {
  final String _openShotBaseUrl;
  final String _openShotToken;

  OpenShotClipService({
    required String openShotBaseUrl,
    required String openShotToken,
  })  : _openShotBaseUrl = openShotBaseUrl,
        _openShotToken = openShotToken;

  /// Create a clip from a file with specified start and end times
  Future<Map<String, dynamic>> createClip({
    required String projectUrl,
    required String fileUrl,
    required double position,
    required double start,
    required double end,
    required int layer,
    Map<String, dynamic>? effects,
  }) async {
    final response = await http.post(
      Uri.parse('$_openShotBaseUrl/clips/'),
      headers: {
        'Authorization': 'Token $_openShotToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'project': projectUrl,
        'file': fileUrl,
        'position': position,
        'start': start,
        'end': end,
        'layer': layer,
        'json': jsonEncode({
          'gravity': 'center',
          'scale': {
            'Points': [
              {
                'co': {'Y': 1, 'X': 1},
                'interpolation': 2
              }
            ]
          },
          'location_x': {
            'Points': [
              {
                'co': {'Y': 0, 'X': 1},
                'interpolation': 2
              }
            ]
          },
          'location_y': {
            'Points': [
              {
                'co': {'Y': 0, 'X': 1},
                'interpolation': 2
              }
            ]
          },
          'alpha': {
            'Points': [
              {
                'co': {'Y': 1, 'X': 1},
                'interpolation': 2
              }
            ]
          },
          'volume': {
            'Points': [
              {
                'co': {'Y': 1, 'X': 1},
                'interpolation': 2
              }
            ]
          },
          ...?effects,
        }),
      }),
    );

    final clipData = jsonDecode(response.body);
    final clipId = clipData['id'];
    final clipUrl = clipData['url'];

    if (clipId == null || clipUrl == null) {
      throw Exception(
          'Failed to get clip ID or URL from response: ${response.body}');
    }

    return clipData;
  }

  /// Apply a preset effect to a clip
  Future<void> applyPreset({
    required String clipId,
    required String presetName,
    Map<String, dynamic>? customParameters,
  }) async {
    final response = await http.post(
      Uri.parse('$_openShotBaseUrl/clips/$clipId/presets/'),
      headers: {
        'Authorization': 'Token $_openShotToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': presetName,
        'parameters': customParameters,
      }),
    );

    final presetData = jsonDecode(response.body);
    if (!presetData['success']) {
      throw Exception('Failed to apply preset: ${response.body}');
    }
  }

  /// Add keyframe animation to a clip
  Future<void> addKeyframes({
    required String clipId,
    required String property,
    required List<Map<String, dynamic>> keyframes,
  }) async {
    final response = await http.post(
      Uri.parse('$_openShotBaseUrl/clips/$clipId/keyframes/'),
      headers: {
        'Authorization': 'Token $_openShotToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'property': property,
        'points': keyframes,
      }),
    );

    final keyframeData = jsonDecode(response.body);
    if (!keyframeData['success']) {
      throw Exception('Failed to add keyframes: ${response.body}');
    }
  }

  /// Reset all effects and animations on a clip
  Future<void> resetClip(String clipId) async {
    final response = await http.post(
      Uri.parse('$_openShotBaseUrl/clips/$clipId/reset/'),
      headers: {
        'Authorization': 'Token $_openShotToken',
      },
    );

    final resetData = jsonDecode(response.body);
    if (!resetData['success']) {
      throw Exception('Failed to reset clip: ${response.body}');
    }
  }
}

/// Available effect presets in OpenShot
class OpenShotEffects {
  // Visual Effects
  static const String bars = 'Bars';
  static const String blur = 'Blur';
  static const String wave = 'Wave';
  static const String shift = 'Shift';
  static const String stabilizer = 'Stabilizer';
  static const String objectDetector = 'Object Detector';
  static const String tracker = 'Tracker';

  // Audio Effects
  static const String noise = 'Noise';
  static const String delay = 'Delay';
  static const String echo = 'Echo';
  static const String distortion = 'Distortion';
  static const String parametricEQ = 'Parametric EQ';
  static const String compressor = 'Compressor';
  static const String expander = 'Expander';
  static const String robotization = 'Robotization';
  static const String whisperization = 'Whisperization';

  // Effect Categories
  static const List<String> visualEffects = [
    bars,
    blur,
    wave,
    shift,
    stabilizer,
    objectDetector,
    tracker,
  ];

  static const List<String> audioEffects = [
    noise,
    delay,
    echo,
    distortion,
    parametricEQ,
    compressor,
    expander,
    robotization,
    whisperization,
  ];

  // Get all effects
  static List<String> get allEffects => [...visualEffects, ...audioEffects];
}

/// Properties that can be animated with keyframes
class OpenShotProperties {
  static const String alpha = 'alpha';
  static const String scaleX = 'scale_x';
  static const String scaleY = 'scale_y';
  static const String locationX = 'location_x';
  static const String locationY = 'location_y';
  static const String rotation = 'rotation';
  static const String time = 'time';
  static const String volume = 'volume';
  static const String shearX = 'shear_x';
  static const String shearY = 'shear_y';
}
