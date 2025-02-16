import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:path/path.dart' as path;

class JamendoMusic {
  final String id;
  final String name;
  final String artist;
  final String duration;
  final String audioUrl;
  final String waveformUrl;
  final bool isStreamable;
  final bool audiodownloadAllowed;
  final String previewUrl;
  final String thumbnailUrl;

  JamendoMusic({
    required this.id,
    required this.name,
    required this.artist,
    required this.duration,
    required this.audioUrl,
    required this.waveformUrl,
    required this.isStreamable,
    required this.audiodownloadAllowed,
    required this.previewUrl,
    required this.thumbnailUrl,
  });

  factory JamendoMusic.fromJson(Map<String, dynamic> json) {
    final durationInSeconds =
        int.tryParse(json['duration']?.toString() ?? '0') ?? 0;

    // Check if audio download is allowed
    final bool audiodownloadAllowed = json['audiodownload_allowed'] == true;

    // Get the appropriate audio URL based on permissions
    String audioUrl = '';
    String previewUrl = '';

    // First try the streaming URL
    if (json['audio'] != null && json['audio'].toString().isNotEmpty) {
      audioUrl = json['audio'].toString();
      // Construct preview URL by adding preview parameter
      final audioUri = Uri.parse(audioUrl);
      final queryParams = Map<String, String>.from(audioUri.queryParameters);
      queryParams['preview'] = '1';
      previewUrl = audioUri.replace(queryParameters: queryParams).toString();
    }

    // If download is allowed, prefer the download URL
    if (audiodownloadAllowed && json['audiodownload'] != null) {
      final downloadUrl = json['audiodownload'].toString();
      if (downloadUrl.isNotEmpty) {
        audioUrl = downloadUrl;
      }
    }

    // Get thumbnail URL with default size if not specified
    String thumbnailUrl = '';
    if (json['image'] != null) {
      thumbnailUrl = json['image'].toString();
    } else if (json['album_image'] != null) {
      thumbnailUrl = json['album_image'].toString();
    }

    // If no image URL is found, construct one using the track ID
    if (thumbnailUrl.isEmpty && json['id'] != null) {
      thumbnailUrl =
          'https://usercontent.jamendo.com?type=album&id=${json['album_id']}&width=300&trackid=${json['id']}';
    }

    return JamendoMusic(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      artist: json['artist_name']?.toString() ?? '',
      duration:
          '${(durationInSeconds ~/ 60).toString().padLeft(2, '0')}:${(durationInSeconds % 60).toString().padLeft(2, '0')}',
      audioUrl: audioUrl,
      waveformUrl: json['waveform']?.toString() ?? '',
      isStreamable: audioUrl.isNotEmpty,
      audiodownloadAllowed: audiodownloadAllowed,
      previewUrl: previewUrl,
      thumbnailUrl: thumbnailUrl,
    );
  }

  static String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}

class JamendoService {
  final String _baseUrl = 'https://api.jamendo.com/v3.0';
  final String? _apiKey = dotenv.env['JAMENDO_CLIENT_ID'];
  final _client = http.Client();

  // Cache for search results
  final Map<String, List<JamendoMusic>> _searchCache = {};
  final Map<String, DateTime> _searchCacheTimestamp = {};
  final Duration _cacheDuration = const Duration(minutes: 30);

  // Cache for downloaded audio files
  final Map<String, String> _audioFileCache = {};

  Future<String> _getCacheDirectory() async {
    final dir = await getTemporaryDirectory();
    final cacheDir = Directory('${dir.path}/jamendo_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir.path;
  }

  Future<String?> _getCachedAudioFile(String trackId) async {
    if (_audioFileCache.containsKey(trackId)) {
      final cachedPath = _audioFileCache[trackId]!;
      if (await File(cachedPath).exists()) {
        return cachedPath;
      }
    }
    return null;
  }

  Future<void> _cacheAudioFile(String trackId, String url) async {
    try {
      print('[JamendoService] Starting to cache audio file for track $trackId');
      final cacheDir = await _getCacheDirectory();
      final fileName = 'track_$trackId.mp3';
      final filePath = path.join(cacheDir, fileName);

      if (!await File(filePath).exists()) {
        print('[JamendoService] File not in cache, downloading from: $url');
        final response = await _client.get(Uri.parse(url));
        if (response.statusCode == 200) {
          print(
              '[JamendoService] Download successful, writing to cache: $filePath');
          await File(filePath).writeAsBytes(response.bodyBytes);
          _audioFileCache[trackId] = filePath;
          print(
              '[JamendoService] Successfully cached audio file for track $trackId');
        } else {
          print(
              '[JamendoService] Failed to download file: HTTP ${response.statusCode}');
        }
      } else {
        print('[JamendoService] File already in cache: $filePath');
        _audioFileCache[trackId] = filePath;
      }
    } catch (e, stackTrace) {
      print('[JamendoService] Error caching audio file for track $trackId:');
      print('[JamendoService] Error: $e');
      print('[JamendoService] Stack trace: $stackTrace');
    }
  }

  void dispose() {
    print('[JamendoService] Disposing service and closing HTTP client');
    _client.close();
  }

  Future<List<JamendoMusic>> searchMusic({
    String query = '',
    String? tags,
    int limit = 20,
    int offset = 0,
  }) async {
    print(
        '[JamendoService] Searching music with query: "$query", tags: ${tags ?? 'none'}, limit: $limit, offset: $offset');

    // Check cache first
    final cacheKey = '${query}_${tags ?? ''}_${limit}_${offset}';
    if (_searchCache.containsKey(cacheKey)) {
      final cacheTimestamp = _searchCacheTimestamp[cacheKey];
      if (cacheTimestamp != null &&
          DateTime.now().difference(cacheTimestamp) < _cacheDuration) {
        print('[JamendoService] Returning cached results for key: $cacheKey');
        return _searchCache[cacheKey]!;
      }
      print('[JamendoService] Cache expired for key: $cacheKey');
    }

    if (_apiKey == null) {
      print(
          '[JamendoService] ERROR: API key not found in environment variables');
      throw Exception('Jamendo API key not found in environment variables');
    }

    final queryParams = {
      'client_id': _apiKey,
      'format': 'json',
      'limit': limit.toString(),
      'offset': offset.toString(),
      'include': 'musicinfo stats licenses',
      'audioformat': 'mp32',
    };

    if (query.isNotEmpty) {
      queryParams['namesearch'] = query;
    }

    if (tags != null && tags.isNotEmpty) {
      queryParams['tags'] = tags;
    }

    try {
      final uri =
          Uri.parse('$_baseUrl/tracks/').replace(queryParameters: queryParams);
      print(
          '[JamendoService] Making API request to: ${uri.toString().replaceAll(_apiKey!, '[REDACTED]')}');

      final response = await _client.get(uri);
      print('[JamendoService] Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['results'] == null) {
          print('[JamendoService] No results found in API response');
          print('[JamendoService] Response body: ${response.body}');
          return [];
        }

        final results = data['results'] as List;
        print(
            '[JamendoService] Found ${results.length} tracks in API response');

        final tracks = results
            .map((track) {
              final jamendoTrack = JamendoMusic.fromJson(track);
              print(
                  '[JamendoService] Processing track ${jamendoTrack.id} - ${jamendoTrack.name}:');
              print('[JamendoService]   - Artist: ${jamendoTrack.artist}');
              print('[JamendoService]   - Duration: ${jamendoTrack.duration}');
              print(
                  '[JamendoService]   - Is Streamable: ${jamendoTrack.isStreamable}');
              print(
                  '[JamendoService]   - Download Allowed: ${jamendoTrack.audiodownloadAllowed}');
              return jamendoTrack;
            })
            .where((track) => track.isStreamable)
            .toList();

        print(
            '[JamendoService] Filtered to ${tracks.length} streamable tracks');

        // Cache the results before returning
        _searchCache[cacheKey] = tracks;
        _searchCacheTimestamp[cacheKey] = DateTime.now();
        print('[JamendoService] Results cached with key: $cacheKey');

        // Start caching audio files in the background
        print('[JamendoService] Starting background caching of audio files');
        for (final track in tracks) {
          _cacheAudioFile(track.id, track.audioUrl);
        }

        return tracks;
      } else {
        print('[JamendoService] API Error Response: ${response.body}');
        throw Exception('Error searching music: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      print('[JamendoService] Exception during API call:');
      print('[JamendoService] Error: $e');
      print('[JamendoService] Stack trace: $stackTrace');
      throw Exception('Error searching music: $e');
    }
  }

  String _extractJamendoTrackId(String url) {
    print('[JamendoService] Extracting track ID from URL: $url');
    try {
      final uri = Uri.parse(url);

      // First try to get trackid from query parameters
      String? trackId = uri.queryParameters['trackid'];
      if (trackId != null) {
        print('[JamendoService] Found track ID in query parameters: $trackId');
        return trackId;
      }

      // If not found, try format=mp31&from=app-devsite pattern
      if (uri.queryParameters['format'] == 'mp31') {
        trackId = uri.queryParameters['trackid'];
        if (trackId != null) {
          print(
              '[JamendoService] Found track ID in mp31 format parameters: $trackId');
          return trackId;
        }
      }

      // If still not found, try the path segments
      trackId = uri.pathSegments.lastWhere(
        (segment) => int.tryParse(segment) != null,
        orElse: () => '',
      );

      if (trackId.isNotEmpty) {
        print('[JamendoService] Found track ID in path segments: $trackId');
        return trackId;
      }

      print('[JamendoService] Failed to extract track ID from URL');
      throw Exception('Invalid Jamendo URL format');
    } catch (e, stackTrace) {
      print('[JamendoService] Error parsing Jamendo URL:');
      print('[JamendoService] Error: $e');
      print('[JamendoService] Stack trace: $stackTrace');
      throw Exception('Invalid Jamendo URL: $e');
    }
  }

  Future<String> downloadMusic(String url,
      {Function(double)? onProgress}) async {
    print('Starting download for URL: $url');
    if (url.isEmpty) {
      print('Error: Empty URL provided');
      throw Exception('Invalid audio URL');
    }

    try {
      final uri = Uri.parse(url);
      if (!uri.isAbsolute || (uri.scheme != 'http' && uri.scheme != 'https')) {
        print('Error: Invalid URL format - ${uri.toString()}');
        throw Exception('Invalid audio URL format');
      }

      // Handle both streaming and download URLs
      String downloadUrl = url;
      if (url.contains('format=mp31')) {
        // Convert streaming URL to download URL if needed
        downloadUrl = url
            .replaceAll('format=mp31', 'format=mp32')
            .replaceAll('from=app-devsite', 'download=1');
      }

      // Extract track ID from URL
      final trackId = _extractJamendoTrackId(url);
      print('Track ID extracted: $trackId');

      // Check cache first
      final cachedPath = await _getCachedAudioFile(trackId);
      if (cachedPath != null) {
        print('Found cached file at: $cachedPath');
        onProgress?.call(1.0); // Complete if cached
        return cachedPath;
      }
      print('No cached file found, starting download');

      // If not cached, download with progress
      final response =
          await _client.send(http.Request('GET', Uri.parse(downloadUrl)));
      final contentLength = response.contentLength ?? 0;
      print('Download started. Total size: ${contentLength} bytes');

      final bytes = <int>[];
      var received = 0;
      var lastProgressLog = 0.0;

      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
        received += chunk.length;
        if (contentLength > 0) {
          final progress = received / contentLength;
          // Log every 10% progress
          if (progress - lastProgressLog >= 0.1) {
            print('Download progress: ${(progress * 100).toStringAsFixed(1)}%');
            lastProgressLog = progress;
          }
          onProgress?.call(progress);
        }
      }

      // Cache the downloaded file
      final cacheDir = await _getCacheDirectory();
      final fileName = 'track_$trackId.mp3';
      final filePath = path.join(cacheDir, fileName);
      print('Saving file to: $filePath');
      await File(filePath).writeAsBytes(bytes);
      _audioFileCache[trackId] = filePath;

      print('Download completed successfully');
      onProgress?.call(1.0); // Complete
      return filePath;
    } catch (e) {
      print('Error during download: $e');
      onProgress?.call(0.0); // Reset on error
      throw Exception('Error processing audio URL: $e');
    }
  }

  void clearCache() async {
    _searchCache.clear();
    _searchCacheTimestamp.clear();
    _audioFileCache.clear();

    try {
      final cacheDir = Directory(await _getCacheDirectory());
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
      }
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }
}
