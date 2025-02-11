import 'package:dartz/dartz.dart';
import '../entities/video_comment.dart';
import '../../../core/error/failures.dart';

abstract class VideoCommentRepository {
  /// Watch comments for a specific media asset
  Stream<List<VideoComment>> watchAssetComments(String projectId, String assetId);

  /// Add a new comment
  Future<Either<Failure, VideoComment>> addComment({
    required String projectId,
    required String assetId,
    required String text,
    required Duration timestamp,
  });

  /// Update an existing comment
  Future<Either<Failure, VideoComment>> updateComment({
    required String commentId,
    required String text,
  });

  /// Delete a comment
  Future<Either<Failure, void>> deleteComment(String commentId);

  /// Get all comments for a project
  Future<Either<Failure, List<VideoComment>>> getProjectComments(String projectId);
}
