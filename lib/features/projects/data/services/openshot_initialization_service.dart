import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class OpenShotInitializationService {
  final String _openShotBaseUrl;
  final String _openShotToken;
  bool _isInitialized = false;
  String? _currentProjectId;
  String? _currentProjectUrl;

  OpenShotInitializationService({
    String? openShotBaseUrl,
    String? openShotToken,
  })  : _openShotBaseUrl = _validateUrl(
            openShotBaseUrl ?? dotenv.env['OPENSHOT_API_URL'] ?? ''),
        _openShotToken =
            openShotToken ?? dotenv.env['OPENSHOT_API_TOKEN'] ?? '';

  bool get isInitialized => _isInitialized;
  String? get currentProjectId => _currentProjectId;
  String? get currentProjectUrl => _currentProjectUrl;

  static String _validateUrl(String url) {
    if (url.isEmpty) {
      throw Exception('OpenShot API URL cannot be empty');
    }
    if (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'http://$url';
    }
    return url;
  }

  Future<void> initialize() async {
    try {
      // First try to load existing project
      final projectData = await _loadExistingProject();
      if (projectData != null) {
        // Verify if project is still valid
        final isValid = await _verifyProject(projectData['project_id']);
        if (isValid) {
          _currentProjectId = projectData['project_id'].toString();
          _currentProjectUrl = projectData['project_url'];
          _isInitialized = true;
          print(
              'Successfully verified existing OpenShot project: $_currentProjectId');
          return;
        }
      }

      // If we get here, we need to create a new project
      print('Creating new OpenShot base project...');
      final newProject = await _createProject();
      await _saveProjectData(newProject);

      _currentProjectId = newProject['project_id'].toString();
      _currentProjectUrl = newProject['project_url'];
      _isInitialized = true;
      print('Successfully created new OpenShot project: $_currentProjectId');
    } catch (e) {
      print('Failed to initialize OpenShot project: $e');
      _isInitialized = false;
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> _loadExistingProject() async {
    try {
      // Try loading from assets first
      final jsonString =
          await rootBundle.loadString('scripts/openshot_project.json');
      return jsonDecode(jsonString);
    } catch (e) {
      print('Could not load existing project: $e');
      return null;
    }
  }

  Future<bool> _verifyProject(dynamic projectId) async {
    try {
      final response = await http.get(
        Uri.parse('$_openShotBaseUrl/projects/$projectId/'),
        headers: {
          'Authorization': 'Token $_openShotToken',
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error verifying project: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>> _createProject() async {
    final response = await http.post(
      Uri.parse('$_openShotBaseUrl/projects/'),
      headers: {
        'Authorization': 'Token $_openShotToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'name': 'CookCut_Base',
        'width': 1920,
        'height': 1080,
        'fps_num': 30,
        'fps_den': 1,
        'sample_rate': 44100,
        'channels': 2,
        'channel_layout': 3,
        'json': jsonEncode({
          'app': 'cookcut',
          'version': '1.0.0',
          'created_at': DateTime.now().toIso8601String(),
          'is_base_project': true,
        }),
      }),
    );

    final projectData = jsonDecode(response.body);
    final projectId = projectData['id'];
    final projectUrl = projectData['url'];

    if (projectId == null || projectUrl == null) {
      throw Exception(
          'Failed to get project ID or URL from response: ${response.body}');
    }

    _currentProjectId = projectId.toString();
    _currentProjectUrl = projectUrl;
    _isInitialized = true;

    print('OpenShot base project initialized with ID: $_currentProjectId');

    return {
      'project_id': projectId,
      'project_url': projectUrl,
      'created_at': DateTime.now().toIso8601String()
    };
  }

  Future<void> _saveProjectData(Map<String, dynamic> projectData) async {
    final jsonString = jsonEncode(projectData);

    // Save to scripts directory
    try {
      final file = File('scripts/openshot_project.json');
      await file.writeAsString(jsonString, flush: true);
      print('Saved project data to scripts/openshot_project.json');
    } catch (e) {
      print('Warning: Could not save to scripts directory: $e');

      // Fallback to app documents directory
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final file =
            File(path.join(appDir.path, 'scripts', 'openshot_project.json'));
        await file.parent.create(recursive: true);
        await file.writeAsString(jsonString, flush: true);
        print('Saved project data to app documents: ${file.path}');
      } catch (e) {
        print('Error: Could not save project data anywhere: $e');
        throw Exception('Failed to save project data');
      }
    }
  }
}
