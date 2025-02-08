import '../entities/media_asset.dart';

abstract class MediaRepository {
  /// Upload a media file to storage and create a MediaAsset record
  Future<MediaAsset> uploadMedia({
    required String projectId,
    required String filePath,
    required MediaType type,
    Map<String, dynamic> metadata = const {},
  });

  /// Get all media assets for a project
  Future<List<MediaAsset>> getProjectMedia(String projectId);

  /// Delete a media asset and its associated file
  Future<void> deleteMedia(MediaAsset asset);

  /// Generate a thumbnail for a video file
  Future<String?> generateThumbnail(String videoPath);

  /// Get the download URL for a media asset
  Future<String> getDownloadUrl(MediaAsset asset);
}
