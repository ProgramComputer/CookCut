import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path/path.dart' as path;
import 'package:mime/mime.dart';
import '../../domain/entities/media_asset.dart';

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

    // Upload to Supabase Storage
    final storagePath = 'projects/$projectId/media/${type.name}/$fileName';
    final storageResponse = await _supabase.storage.from('media').upload(
          storagePath,
          file,
          fileOptions: FileOptions(
            contentType: mimeType,
          ),
        );

    // Get the public URL
    final fileUrl = _supabase.storage.from('media').getPublicUrl(storagePath);

    // Create Firestore document for metadata
    final docRef = await _firestore
        .collection('projects')
        .doc(projectId)
        .collection('media_assets')
        .add({
      'fileName': fileName,
      'fileUrl': fileUrl,
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
      metadata: metadata,
    );
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
