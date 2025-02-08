import 'dart:io';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path/path.dart' as path;
import 'package:mime/mime.dart';
import 'package:video_player/video_player.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/media_asset.dart';
import '../../domain/repositories/media_repository.dart';
import '../services/media_processing_service.dart';

class MediaRepositoryImpl implements MediaRepository {
  final FirebaseFirestore _firestore;
  final SupabaseClient _supabase;
  final MediaProcessingService _mediaProcessingService;
  final FirebaseAuth _auth;

  MediaRepositoryImpl({
    FirebaseFirestore? firestore,
    SupabaseClient? supabase,
    FirebaseAuth? auth,
    required MediaProcessingService mediaProcessingService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _supabase = supabase ?? Supabase.instance.client,
        _auth = auth ?? FirebaseAuth.instance,
        _mediaProcessingService = mediaProcessingService;

  @override
  Future<MediaAsset> uploadMedia({
    required String projectId,
    required String filePath,
    required MediaType type,
    Map<String, dynamic> metadata = const {},
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File does not exist: $filePath');
    }

    final fileName = path.basename(filePath);
    final mimeType = lookupMimeType(filePath);
    if (mimeType == null) {
      throw Exception('Could not determine file type');
    }

    // Generate thumbnail for video files
    String? thumbnailUrl;
    if (type == MediaType.rawFootage || type == MediaType.editedClip) {
      try {
        thumbnailUrl =
            await _mediaProcessingService.generateThumbnail(filePath);
      } catch (e) {
        print('Warning: Failed to generate thumbnail: $e');
        // Continue with upload even if thumbnail generation fails
      }
    }

    // Upload file to Supabase Storage
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    final storagePath =
        'projects/$projectId/media/${type.name.toLowerCase()}/$fileName';

    // Upload the file
    await _supabase.storage.from('cookcut-media').upload(storagePath, file,
        fileOptions: FileOptions(
          contentType: mimeType,
          upsert: true,
        ));

    // Get the public URL
    final downloadUrl = await _supabase.storage
        .from('cookcut-media')
        .createSignedUrl(storagePath, 60 * 60 * 24 * 7); // 7 days expiry

    // Create Firestore document
    final docRef = await _firestore
        .collection('projects')
        .doc(projectId)
        .collection('media_assets')
        .add({
      'fileName': fileName,
      'fileUrl': downloadUrl,
      'thumbnailUrl': thumbnailUrl,
      'type': type.name,
      'fileSize': await file.length(),
      'uploadedAt': FieldValue.serverTimestamp(),
      'metadata': metadata,
    });

    return MediaAsset(
      id: docRef.id,
      projectId: projectId,
      type: type,
      fileUrl: downloadUrl,
      fileName: fileName,
      fileSize: await file.length(),
      uploadedAt: DateTime.now(),
      thumbnailUrl: thumbnailUrl,
      metadata: metadata,
    );
  }

  @override
  Future<List<MediaAsset>> getProjectMedia(String projectId) async {
    final snapshot = await _firestore
        .collection('projects')
        .doc(projectId)
        .collection('media_assets')
        .orderBy('uploadedAt', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return MediaAsset(
        id: doc.id,
        projectId: projectId,
        type: MediaType.values.firstWhere(
          (e) => e.name == data['type'],
          orElse: () => MediaType.rawFootage,
        ),
        fileUrl: data['fileUrl'],
        fileName: data['fileName'],
        fileSize: data['fileSize'],
        uploadedAt: (data['uploadedAt'] as Timestamp).toDate(),
        thumbnailUrl: data['thumbnailUrl'],
        metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
      );
    }).toList();
  }

  @override
  Future<void> deleteMedia(MediaAsset asset) async {
    final storagePath =
        'projects/${asset.projectId}/media/${asset.type.name.toLowerCase()}/${asset.fileName}';

    // Delete from Supabase Storage
    await _supabase.storage.from('cookcut-media').remove([storagePath]);

    // Delete thumbnail if exists
    if (asset.thumbnailUrl != null) {
      final thumbnailPath =
          'projects/${asset.projectId}/media/${asset.type.name.toLowerCase()}/thumbnails/${asset.fileName.split('.').first}_thumb.jpg';
      await _supabase.storage.from('cookcut-media').remove([thumbnailPath]);
    }

    // Delete from Firestore
    await _firestore
        .collection('projects')
        .doc(asset.projectId)
        .collection('media_assets')
        .doc(asset.id)
        .delete();
  }

  @override
  Future<String?> generateThumbnail(String videoPath) async {
    try {
      return await _mediaProcessingService.generateThumbnail(videoPath);
    } catch (e) {
      print('Error generating thumbnail: $e');
      return null;
    }
  }

  @override
  Future<String?> uploadVideo(String videoPath) async {
    try {
      final file = File(videoPath);
      final fileName = videoPath.split('/').last;
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      final storagePath = 'users/$userId/videos/$fileName';

      // Upload video to Supabase Storage
      await _supabase.storage.from('cookcut-media').upload(storagePath, file,
          fileOptions: FileOptions(
            contentType: 'video/mp4',
            upsert: true,
          ));

      // Get public URL
      final urlResponse = await _supabase.storage
          .from('cookcut-media')
          .createSignedUrl(storagePath, 60 * 60 * 24 * 7); // 7 days expiry

      return urlResponse;
    } catch (e) {
      print('Error uploading video: $e');
      return null;
    }
  }

  @override
  Future<String?> compressVideo(String videoPath) async {
    try {
      return await _mediaProcessingService.compressVideo(videoPath);
    } catch (e) {
      print('Error compressing video: $e');
      return null;
    }
  }

  @override
  Future<String?> transcodeVideo(String videoPath, String format) async {
    try {
      return await _mediaProcessingService.transcodeVideo(videoPath, format);
    } catch (e) {
      print('Error transcoding video: $e');
      return null;
    }
  }

  @override
  Future<String> getDownloadUrl(MediaAsset asset) async {
    final storagePath =
        'projects/${asset.projectId}/media/${asset.type.name.toLowerCase()}/${asset.fileName}';
    return await _supabase.storage
        .from('cookcut-media')
        .createSignedUrl(storagePath, 60 * 60 * 24 * 7); // 7 days expiry
  }
}
