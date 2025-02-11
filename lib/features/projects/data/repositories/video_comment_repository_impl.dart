import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dartz/dartz.dart';
import '../../domain/entities/video_comment.dart';
import '../../domain/repositories/video_comment_repository.dart';
import '../../../core/error/failures.dart';

class VideoCommentRepositoryImpl implements VideoCommentRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  VideoCommentRepositoryImpl({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  @override
  Stream<List<VideoComment>> watchAssetComments(
      String projectId, String assetId) {
    return _firestore
        .collection('projects')
        .doc(projectId)
        .collection('media_assets')
        .doc(assetId)
        .collection('comments')
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              return VideoComment(
                id: doc.id,
                projectId: projectId,
                assetId: assetId,
                authorId: data['authorId'] as String,
                authorName: data['authorName'] as String? ?? 'Anonymous',
                authorAvatarUrl: data['authorAvatarUrl'] as String?,
                text: data['text'] as String,
                timestamp: Duration(milliseconds: data['timestamp'] as int),
                createdAt: (data['createdAt'] as Timestamp).toDate(),
                updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
              );
            }).toList());
  }

  @override
  Future<Either<Failure, VideoComment>> addComment({
    required String projectId,
    required String assetId,
    required String text,
    required Duration timestamp,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return Left(InsufficientPermissionsFailure());
      }

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        return Left(UserNotFoundFailure());
      }

      final now = DateTime.now();
      final commentData = {
        'authorId': user.uid,
        'authorName': userDoc.data()?['displayName'] as String? ?? 'Anonymous',
        'authorAvatarUrl': userDoc.data()?['photoURL'] as String?,
        'text': text,
        'timestamp': timestamp.inMilliseconds,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': null,
      };

      final docRef = await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('media_assets')
          .doc(assetId)
          .collection('comments')
          .add(commentData);

      return Right(VideoComment(
        id: docRef.id,
        projectId: projectId,
        assetId: assetId,
        authorId: user.uid,
        authorName: commentData['authorName'] as String,
        authorAvatarUrl: commentData['authorAvatarUrl'] as String?,
        text: text,
        timestamp: timestamp,
        createdAt: now,
        updatedAt: null,
      ));
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, VideoComment>> updateComment({
    required String commentId,
    required String text,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return Left(InsufficientPermissionsFailure());
      }

      // Get all projects where the user has access
      final projectsQuery = await _firestore
          .collection('projects')
          .where('user_id', isEqualTo: user.uid)
          .get();

      // Search for the comment in each project's media assets
      for (final projectDoc in projectsQuery.docs) {
        final mediaAssetsQuery = await _firestore
            .collection('projects')
            .doc(projectDoc.id)
            .collection('media_assets')
            .get();

        for (final assetDoc in mediaAssetsQuery.docs) {
          final commentDoc = await _firestore
              .collection('projects')
              .doc(projectDoc.id)
              .collection('media_assets')
              .doc(assetDoc.id)
              .collection('comments')
              .doc(commentId)
              .get();

          if (commentDoc.exists) {
            final data = commentDoc.data()!;

            // Check if the user is the author
            if (data['authorId'] != user.uid) {
              return Left(InsufficientPermissionsFailure());
            }

            final now = DateTime.now();
            await commentDoc.reference.update({
              'text': text,
              'updatedAt': Timestamp.fromDate(now),
            });

            return Right(VideoComment(
              id: commentDoc.id,
              projectId: projectDoc.id,
              assetId: assetDoc.id,
              authorId: data['authorId'] as String,
              authorName: data['authorName'] as String? ?? 'Anonymous',
              authorAvatarUrl: data['authorAvatarUrl'] as String?,
              text: text,
              timestamp: Duration(milliseconds: data['timestamp'] as int),
              createdAt: (data['createdAt'] as Timestamp).toDate(),
              updatedAt: now,
            ));
          }
        }
      }

      return Left(CommentNotFoundFailure());
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, void>> deleteComment(String commentId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return Left(InsufficientPermissionsFailure());
      }

      // Get all projects where the user has access
      final projectsQuery = await _firestore
          .collection('projects')
          .where('user_id', isEqualTo: user.uid)
          .get();

      // Search for the comment in each project's media assets
      for (final projectDoc in projectsQuery.docs) {
        final mediaAssetsQuery = await _firestore
            .collection('projects')
            .doc(projectDoc.id)
            .collection('media_assets')
            .get();

        for (final assetDoc in mediaAssetsQuery.docs) {
          final commentDoc = await _firestore
              .collection('projects')
              .doc(projectDoc.id)
              .collection('media_assets')
              .doc(assetDoc.id)
              .collection('comments')
              .doc(commentId)
              .get();

          if (commentDoc.exists) {
            final data = commentDoc.data()!;

            // Check if the user is the author
            if (data['authorId'] != user.uid) {
              return Left(InsufficientPermissionsFailure());
            }

            await commentDoc.reference.delete();
            return const Right(null);
          }
        }
      }

      return Left(CommentNotFoundFailure());
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, List<VideoComment>>> getProjectComments(
      String projectId) async {
    try {
      final commentsQuery = await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('media_assets')
          .get();

      final comments = <VideoComment>[];
      for (final assetDoc in commentsQuery.docs) {
        final commentsSnapshot = await assetDoc.reference
            .collection('comments')
            .orderBy('timestamp', descending: false)
            .get();

        comments.addAll(commentsSnapshot.docs.map((doc) {
          final data = doc.data();
          return VideoComment(
            id: doc.id,
            projectId: projectId,
            assetId: assetDoc.id,
            authorId: data['authorId'] as String,
            authorName: data['authorName'] as String? ?? 'Anonymous',
            authorAvatarUrl: data['authorAvatarUrl'] as String?,
            text: data['text'] as String,
            timestamp: Duration(milliseconds: data['timestamp'] as int),
            createdAt: (data['createdAt'] as Timestamp).toDate(),
            updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
          );
        }));
      }

      return Right(comments);
    } catch (e) {
      return Left(ServerFailure());
    }
  }
}
