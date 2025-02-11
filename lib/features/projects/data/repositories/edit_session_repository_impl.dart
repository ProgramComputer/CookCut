import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dartz/dartz.dart';
import '../../domain/entities/edit_session.dart';
import '../../domain/repositories/edit_session_repository.dart';
import '../../../core/error/failures.dart';

class EditSessionRepositoryImpl implements EditSessionRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  static const sessionTimeout = Duration(minutes: 5);

  EditSessionRepositoryImpl({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  @override
  Future<Either<Failure, EditSession>> startSession(String projectId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        return Left(InsufficientPermissionsFailure());
      }

      // Check if there's an active session
      final currentSession = await getCurrentSession(projectId);
      if (currentSession.isRight()) {
        final session = currentSession.getOrElse(() => null);
        if (session != null) {
          if (session.userId != userId) {
            return Left(SessionInUseFailure());
          }
          // If it's our session, just keep it alive
          await keepSessionAlive(session.id);
          return Right(session);
        }
      }

      // Create new session
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final displayName =
          userDoc.data()?['displayName'] as String? ?? 'Unknown User';

      final now = DateTime.now();
      final sessionRef = _firestore
          .collection('projects')
          .doc(projectId)
          .collection('edit_sessions')
          .doc();

      final session = EditSession(
        id: sessionRef.id,
        projectId: projectId,
        userId: userId,
        userDisplayName: displayName,
        startedAt: now,
        lastActivityAt: now,
      );

      await sessionRef.set({
        'projectId': session.projectId,
        'userId': session.userId,
        'userDisplayName': session.userDisplayName,
        'startedAt': Timestamp.fromDate(session.startedAt),
        'lastActivityAt': Timestamp.fromDate(session.lastActivityAt),
        'isActive': session.isActive,
      });

      return Right(session);
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, void>> endSession(String sessionId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        return Left(InsufficientPermissionsFailure());
      }

      // First get all projects to search through
      final projectsQuery = await _firestore
          .collection('projects')
          .where('user_id', isEqualTo: userId)
          .get();

      // Search for the session in each project
      for (final projectDoc in projectsQuery.docs) {
        final sessionRef = _firestore
            .collection('projects')
            .doc(projectDoc.id)
            .collection('edit_sessions')
            .doc(sessionId);

        final sessionDoc = await sessionRef.get();
        if (sessionDoc.exists) {
          // Use a transaction to ensure atomic update
          await _firestore.runTransaction((transaction) async {
            transaction.update(sessionRef, {
              'isActive': false,
              'lastActivityAt': Timestamp.now(),
              'endedAt': Timestamp.now(), // Add this to help with querying
            });
          });
          return const Right(null);
        }
      }

      return const Right(null);
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, void>> keepSessionAlive(String sessionId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        return Left(InsufficientPermissionsFailure());
      }

      // First get all projects to search through
      final projectsQuery = await _firestore
          .collection('projects')
          .where('user_id', isEqualTo: userId)
          .get();

      // Search for the session in each project
      for (final projectDoc in projectsQuery.docs) {
        final sessionDoc = await _firestore
            .collection('projects')
            .doc(projectDoc.id)
            .collection('edit_sessions')
            .doc(sessionId)
            .get();

        if (sessionDoc.exists) {
          await sessionDoc.reference.update({
            'lastActivityAt': Timestamp.now(),
          });
          return const Right(null);
        }
      }

      return Left(SessionNotFoundFailure());
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, EditSession?>> getCurrentSession(
      String projectId) async {
    try {
      final now = DateTime.now();
      final timeoutThreshold = now.subtract(sessionTimeout);

      final sessionsQuery = await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('edit_sessions')
          .where('isActive', isEqualTo: true)
          .where('lastActivityAt',
              isGreaterThan: Timestamp.fromDate(timeoutThreshold))
          .limit(1)
          .get();

      if (sessionsQuery.docs.isEmpty) {
        return const Right(null);
      }

      final doc = sessionsQuery.docs.first;
      final data = doc.data();

      return Right(EditSession(
        id: doc.id,
        projectId: projectId,
        userId: data['userId'] as String,
        userDisplayName: data['userDisplayName'] as String,
        startedAt: (data['startedAt'] as Timestamp).toDate(),
        lastActivityAt: (data['lastActivityAt'] as Timestamp).toDate(),
        isActive: data['isActive'] as bool,
      ));
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Stream<EditSession?> watchCurrentSession(String projectId) {
    final now = DateTime.now();
    final timeoutThreshold = now.subtract(sessionTimeout);

    return _firestore
        .collection('projects')
        .doc(projectId)
        .collection('edit_sessions')
        .where('isActive', isEqualTo: true)
        .where('lastActivityAt',
            isGreaterThan: Timestamp.fromDate(timeoutThreshold))
        .where('endedAt', isNull: true) // Add this condition
        .orderBy('lastActivityAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) {
        return null;
      }

      final doc = snapshot.docs.first;
      final data = doc.data();

      return EditSession(
        id: doc.id,
        projectId: projectId,
        userId: data['userId'] as String,
        userDisplayName: data['userDisplayName'] as String,
        startedAt: (data['startedAt'] as Timestamp).toDate(),
        lastActivityAt: (data['lastActivityAt'] as Timestamp).toDate(),
        isActive: data['isActive'] as bool,
      );
    });
  }

  @override
  Future<Either<Failure, bool>> canEdit(String projectId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        return const Right(false);
      }

      // Check if user is owner
      final project =
          await _firestore.collection('projects').doc(projectId).get();

      if (!project.exists) {
        return Left(ProjectNotFoundFailure());
      }

      if (project.data()?['user_id'] == userId) {
        return const Right(true);
      }

      // Check if user is editor
      final collaboratorDoc = await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('collaborators')
          .doc(userId)
          .get();

      if (!collaboratorDoc.exists) {
        return const Right(false);
      }

      final role = collaboratorDoc.data()?['role'] as String?;
      return Right(role == 'editor' || role == 'owner');
    } catch (e) {
      return Left(ServerFailure());
    }
  }
}
