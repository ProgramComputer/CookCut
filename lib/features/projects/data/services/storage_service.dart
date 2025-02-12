import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart' as path;
import 'package:mime/mime.dart';
import '../../domain/entities/media_asset.dart';
import 'package:video_compress/video_compress.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:math' as math;

class StorageService {
  final SupabaseClient _supabase;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  StorageService({
    SupabaseClient? supabase,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _supabase = supabase ?? Supabase.instance.client,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

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

    File fileToUpload = file;
    try {
      // Compress video if it's a video file and not an audio file
      if (type != MediaType.audio && (mimeType.startsWith('video/') ?? false)) {
        // Get video metadata first
        final MediaInfo? sourceInfo =
            await VideoCompress.getMediaInfo(file.path);
        if (sourceInfo == null) {
          throw Exception('Could not get video metadata');
        }

        // Determine optimal compression settings based on source
        final VideoQuality targetQuality;

        if (sourceInfo.width == null || sourceInfo.height == null) {
          // Fallback if we can't get dimensions
          targetQuality = VideoQuality.MediumQuality;
        } else {
          final int maxDimension =
              math.max(sourceInfo.width!, sourceInfo.height!);
          if (maxDimension > 1280) {
            // Anything larger than 720p -> compress to medium quality
            targetQuality = VideoQuality.MediumQuality; // This will target 720p
          } else {
            // Already small enough, use lower quality for bitrate optimization
            targetQuality = VideoQuality.LowQuality;
          }
        }

        // Compress video with Android-compatible settings
        final MediaInfo? mediaInfo = await VideoCompress.compressVideo(
          file.path,
          quality: targetQuality,
          deleteOrigin: false,
          includeAudio: true,
        );

        if (mediaInfo == null || mediaInfo.file == null) {
          throw Exception('Video compression failed');
        }

        fileToUpload = mediaInfo.file!;

        // Add compression metadata
        metadata = {
          ...metadata,
          'compression': {
            'originalSize': await file.length(),
            'compressedSize': await fileToUpload.length(),
            'originalWidth': sourceInfo.width,
            'originalHeight': sourceInfo.height,
            'targetQuality': targetQuality.toString(),
          }
        };
      }

      // Map MediaType to storage directory
      final String mediaDir = type == MediaType.audio
          ? 'audio'
          : type == MediaType.editedClip
              ? 'processed'
              : 'raw';

      // Upload to Supabase Storage using the correct structure
      final storagePath = 'media/$projectId/$mediaDir/$fileName';
      await _supabase.storage.from('cookcut-media').upload(
            storagePath,
            fileToUpload,
            fileOptions: FileOptions(
              contentType: mimeType,
            ),
          );

      // Get the public URL
      final fileUrl =
          _supabase.storage.from('cookcut-media').getPublicUrl(storagePath);

      // Create Firestore document for metadata
      final docRef = await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('media_assets')
          .add({
        'fileName': fileName,
        'fileUrl': fileUrl,
        'type': type.name,
        'fileSize': await fileToUpload.length(),
        'uploadedAt': FieldValue.serverTimestamp(),
        'metadata': metadata,
      });

      return MediaAsset(
        id: docRef.id,
        projectId: projectId,
        type: type,
        fileUrl: fileUrl,
        fileName: fileName,
        fileSize: await fileToUpload.length(),
        uploadedAt: DateTime.now(),
        metadata: metadata,
        position: metadata['position'] as int? ?? 0,
      );
    } catch (e) {
      print('Error in media upload: $e');
      rethrow;
    } finally {
      // Clean up compression cache
      await VideoCompress.deleteAllCache();
    }
  }

  Future<void> deleteMedia(MediaAsset asset) async {
    // Delete from Supabase Storage
    final storagePath = _getStoragePathFromUrl(asset.fileUrl);
    await _supabase.storage.from('media').remove([storagePath]);

    // Delete metadata from Firestore
    await _firestore
        .collection('projects')
        .doc(asset.projectId)
        .collection('media_assets')
        .doc(asset.id)
        .delete();
  }

  String _getStoragePathFromUrl(String url) {
    // Extract the path from the Supabase URL
    // Example URL: https://<project>.supabase.co/storage/v1/object/public/media/projects/...
    final uri = Uri.parse(url);
    final pathSegments = uri.pathSegments;
    return pathSegments.sublist(pathSegments.indexOf('media') + 1).join('/');
  }
}
