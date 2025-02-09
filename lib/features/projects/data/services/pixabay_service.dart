import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PixabayMusic {
  final int id;
  final String title;
  final String duration;
  final String previewUrl;
  final String downloadUrl;
  final String user;
  final String tags;

  PixabayMusic({
    required this.id,
    required this.title,
    required this.duration,
    required this.previewUrl,
    required this.downloadUrl,
    required this.user,
    required this.tags,
  });

  factory PixabayMusic.fromJson(Map<String, dynamic> json) {
    return PixabayMusic(
      id: json['id'],
      title: json['title'],
      duration: json['duration'],
      previewUrl: json['preview_url'],
      downloadUrl: json['download_url'],
      user: json['user'],
      tags: json['tags'],
    );
  }
}

class PixabayService {
  final String _baseUrl = 'https://pixabay.com/api/';
  final String _apiKey;
  final http.Client _client;

  PixabayService({http.Client? client})
      : _client = client ?? http.Client(),
        _apiKey = dotenv.env['PIXABAY_API_KEY'] ?? '';

  Future<List<PixabayMusic>> searchMusic({
    required String query,
    String? category,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final response = await _client.get(
        Uri.parse(
          '$_baseUrl/videos/?key=$_apiKey&q=${Uri.encodeComponent(query)}'
          '${category != null ? '&category=$category' : ''}'
          '&page=$page&per_page=$perPage&audio=true',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return (data['hits'] as List)
            .map((hit) => PixabayMusic.fromJson(hit))
            .toList();
      } else {
        throw Exception('Failed to search music: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error searching music: $e');
    }
  }

  Future<String> downloadMusic(String downloadUrl) async {
    try {
      final response = await _client.get(Uri.parse(downloadUrl));
      if (response.statusCode == 200) {
        // Save to temporary file and return path
        // Implementation will be added when handling file storage
        return '';
      } else {
        throw Exception('Failed to download music: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error downloading music: $e');
    }
  }

  void dispose() {
    _client.close();
  }
}
