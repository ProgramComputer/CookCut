import 'dart:io';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path/path.dart' as path;
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/media_asset.dart';
import '../../domain/repositories/media_repository.dart';
import '../services/media_processing_service.dart';
import '../../domain/entities/video_processing_config.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_video_player_plus/cached_video_player_plus.dart';
import 'package:dartz/dartz.dart';
import 'dart:developer' as developer;

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
    StreamController<double>? progressController,
  }) async {
    final file = File(filePath);
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${path.basename(filePath)}';
    final mimeType = lookupMimeType(filePath);
    String? thumbnailUrl;

    if (!await file.exists()) {
      throw Exception('File does not exist');
    }

    // Generate thumbnail for video files
    if (type != MediaType.audio && (mimeType?.startsWith('video/') ?? false)) {
      thumbnailUrl = await _mediaProcessingService.generateThumbnail(
        filePath,
        projectId: projectId,
      );
    }

    // Determine storage path based on media type
    final mediaFolder = type == MediaType.audio
        ? 'audio'
        : type == MediaType.editedClip
            ? 'processed'
            : 'raw';
    final storagePath = 'media/$projectId/$mediaFolder/$fileName';

    // Upload to Supabase Storage
    try {
      await _supabase.storage.from('cookcut-media').upload(
            storagePath,
            file,
            fileOptions: FileOptions(
              contentType: mimeType,
              upsert: true,
            ),
          );

      // Get the file URL
      final fileUrl =
          _supabase.storage.from('cookcut-media').getPublicUrl(storagePath);

      // Create Firestore document
      final docRef = await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('media_assets')
          .add({
        'fileName': fileName,
        'storagePath': storagePath,
        'fileUrl': fileUrl,
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
        fileUrl: fileUrl,
        fileName: fileName,
        fileSize: await file.length(),
        uploadedAt: DateTime.now(),
        thumbnailUrl: thumbnailUrl,
        metadata: metadata,
        position: metadata['position'] as int? ?? 0,
      );
    } catch (e) {
      // Clean up any uploaded files if the process fails
      try {
        await _supabase.storage.from('cookcut-media').remove([storagePath]);
      } catch (_) {
        // Ignore cleanup errors
      }
      throw Exception('Failed to upload media: ${e.toString()}');
    }
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
        position: data['position'] as int? ?? 0,
      );
    }).toList();
  }

  @override
  Future<void> deleteMedia(MediaAsset asset) async {
    // Get the storage path from Firestore
    final doc = await _firestore
        .collection('projects')
        .doc(asset.projectId)
        .collection('media_assets')
        .doc(asset.id)
        .get();

    if (!doc.exists) {
      throw Exception('Media asset not found');
    }

    final data = doc.data();
    final metadata = data?['metadata'] as Map<String, dynamic>?;

    // Get storage paths
    final videoStoragePath = metadata?['storagePath'] as String?;
    final thumbnailStoragePath = metadata?['thumbnailStoragePath'] as String?;

    if (videoStoragePath == null) {
      throw Exception('Video storage path not found');
    }

    try {
      // Delete video from Supabase Storage
      await _supabase.storage.from('cookcut-media').remove([videoStoragePath]);

      // Delete thumbnail if it exists
      if (thumbnailStoragePath != null) {
        try {
          await _supabase.storage
              .from('cookcut-media')
              .remove([thumbnailStoragePath]);
        } catch (e) {
          // Log but don't fail if thumbnail deletion fails
          developer.log(
            'Failed to delete thumbnail',
            name: 'MediaRepositoryImpl',
            error: e,
          );
        }
      }

      // Delete from Firestore
      await _firestore
          .collection('projects')
          .doc(asset.projectId)
          .collection('media_assets')
          .doc(asset.id)
          .delete();
    } catch (e) {
      throw Exception('Failed to delete media: ${e.toString()}');
    }
  }

  @override
  Future<String?> generateThumbnail(String videoPath,
      {required String projectId}) async {
    return _mediaProcessingService.generateThumbnail(
      videoPath,
      projectId: projectId,
    );
  }

  @override
  Future<String> getDownloadUrl(MediaAsset asset) async {
    final doc = await _firestore
        .collection('projects')
        .doc(asset.projectId)
        .collection('media_assets')
        .doc(asset.id)
        .get();

    if (!doc.exists) {
      throw Exception('Media asset not found');
    }

    final storagePath = doc.data()?['storagePath'] as String?;
    if (storagePath == null) {
      throw Exception('Storage path not found');
    }

    return _supabase.storage
        .from('cookcut-media')
        .createSignedUrl(storagePath, 60 * 60 * 24 * 7); // 7 days expiry
  }

  @override
  Stream<List<MediaAsset>> watchProjectMedia(String projectId) {
    return _firestore
        .collection('projects')
        .doc(projectId)
        .collection('media_assets')
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
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
                position: data['position'] as int? ?? 0,
              );
            }).toList());
  }

  @override
  Future<Either<String, MediaAsset>> processVideo({
    required String videoUrl,
    required String projectId,
    required int position,
    int layer = 0,
  }) async {
    try {
      // Initialize video player to get metadata
      final controller = CachedVideoPlayerPlusController.networkUrl(
        Uri.parse(videoUrl),
      );
      await controller.initialize();

      final duration = controller.value.duration;
      final size = controller.value.size;

      // Clean up controller
      await controller.dispose();

      // Process the video
      final result = await _mediaProcessingService.processVideo(
        videoUrl: videoUrl,
        projectId: projectId,
        position: position,
        layer: layer,
      );

      return right(MediaAsset(
        id: result['id'] as String,
        fileUrl: result['url'] as String,
        fileName: result['fileName'] as String,
        projectId: projectId,
        position: position,
        layer: layer,
        type: MediaType.editedClip,
        fileSize: 0, // Will be updated after processing
        uploadedAt: DateTime.now(),
        duration: duration,
        metadata: {
          'width': size.width.toInt(),
          'height': size.height.toInt(),
        },
      ));
    } catch (e) {
      return left('Error processing video: ${e.toString()}');
    }
  }

  @override
  Future<void> addMediaAsset(MediaAsset asset) async {
    // Create Firestore document
    await _firestore
        .collection('projects')
        .doc(asset.projectId)
        .collection('media_assets')
        .doc(asset.id)
        .set({
      'fileName': asset.fileName,
      'fileUrl': asset.fileUrl,
      'thumbnailUrl': asset.thumbnailUrl,
      'type': asset.type.name,
      'fileSize': asset.fileSize,
      'uploadedAt': Timestamp.fromDate(asset.uploadedAt),
      'metadata': asset.metadata,
      'position': asset.position,
      'layer': asset.layer,
    });
  }
}
