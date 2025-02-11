import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dartz/dartz.dart';
import '../../domain/entities/collaborator.dart';
import '../../domain/entities/collaborator_role.dart';
import '../../domain/repositories/collaborator_repository.dart';
import '../../../core/error/failures.dart';

class CollaboratorRepositoryImpl implements CollaboratorRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollaboratorRepositoryImpl({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// Checks if the current user is the owner of the project
  Future<bool> _isProjectOwner(String projectId) async {
    final project =
        await _firestore.collection('projects').doc(projectId).get();
    return project.exists &&
        project.data()?['user_id'] == _auth.currentUser?.uid;
  }

  @override
  Stream<List<Collaborator>> watchCollaborators(String projectId) {
    return _firestore
        .collection('projects')
        .doc(projectId)
        .collection('collaborators')
        .snapshots()
        .asyncMap((snapshot) async {
      final collaborators = <Collaborator>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        // Fetch user data from users collection
        final userDoc = await _firestore.collection('users').doc(doc.id).get();
        final userData = userDoc.data();

        collaborators.add(Collaborator(
          id: doc.id,
          projectId: projectId,
          userId: doc.id,
          email: userData?['email'] as String?,
          displayName: userData?['displayName'] as String?,
          photoUrl: userData?['photoUrl'] as String?,
          role: CollaboratorRole.values.firstWhere(
            (role) => role.name == data['role'],
            orElse: () => CollaboratorRole.viewer,
          ),
          addedAt: (data['addedAt'] as Timestamp).toDate(),
        ));
      }

      return collaborators;
    });
  }

  @override
  Future<Either<Failure, Collaborator>> addCollaborator({
    required String projectId,
    required String email,
    required CollaboratorRole role,
  }) async {
    try {
      // 1. Check if current user is project owner
      final project =
          await _firestore.collection('projects').doc(projectId).get();
      if (!project.exists ||
          project.data()?['user_id'] != _auth.currentUser?.uid) {
        return Left(InsufficientPermissionsFailure());
      }

      // 2. Find user by email (case insensitive)
      final normalizedEmail = email.toLowerCase();
      final userQuery = await _firestore
          .collection('users')
          .where('email', isEqualTo: normalizedEmail)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        return Left(UserNotFoundFailure());
      }

      final userDoc = userQuery.docs.first;
      final userData = userDoc.data();
      final userId = userDoc.id;

      // 3. Check if user is already a collaborator
      final collaboratorDoc = await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('collaborators')
          .doc(userId)
          .get();

      if (collaboratorDoc.exists) {
        return Left(CollaboratorAlreadyExistsFailure());
      }

      // 4. Add collaborator using user's UID as document ID
      final now = DateTime.now();
      final collaborator = Collaborator(
        id: userId,
        projectId: projectId,
        userId: userId,
        email: userData['email'] as String?,
        displayName: userData['displayName'] as String?,
        photoUrl: userData['photoUrl'] as String?,
        role: role,
        addedAt: now,
      );

      await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('collaborators')
          .doc(userId)
          .set({
        'role': role.name,
        'addedAt': Timestamp.fromDate(now),
        'email': userData['email'],
        'displayName': userData['displayName'],
        'photoUrl': userData['photoUrl'],
      });

      return Right(collaborator);
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, Collaborator>> updateCollaboratorRole({
    required String collaboratorId,
    required CollaboratorRole newRole,
  }) async {
    try {
      // Get all projects where the current user is the owner
      final projectsQuery = await _firestore
          .collection('projects')
          .where('user_id', isEqualTo: _auth.currentUser?.uid)
          .get();

      // Search for the collaborator in each project
      for (final projectDoc in projectsQuery.docs) {
        final collaboratorDoc = await _firestore
            .collection('projects')
            .doc(projectDoc.id)
            .collection('collaborators')
            .doc(collaboratorId)
            .get();

        if (collaboratorDoc.exists) {
          final data = collaboratorDoc.data()!;
          await collaboratorDoc.reference.update({'role': newRole.name});

          return Right(Collaborator(
            id: collaboratorDoc.id,
            projectId: projectDoc.id,
            userId: collaboratorDoc.id,
            email: data['email'] as String?,
            displayName: data['displayName'] as String?,
            photoUrl: data['photoUrl'] as String?,
            role: newRole,
            addedAt: (data['addedAt'] as Timestamp).toDate(),
          ));
        }
      }

      return Left(CollaboratorNotFoundFailure());
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, void>> removeCollaborator(
      String collaboratorId) async {
    try {
      // Get all projects where the current user is the owner
      final projectsQuery = await _firestore
          .collection('projects')
          .where('user_id', isEqualTo: _auth.currentUser?.uid)
          .get();

      // Search for the collaborator in each project
      for (final projectDoc in projectsQuery.docs) {
        final collaboratorDoc = await _firestore
            .collection('projects')
            .doc(projectDoc.id)
            .collection('collaborators')
            .doc(collaboratorId)
            .get();

        if (collaboratorDoc.exists) {
          await collaboratorDoc.reference.delete();
          return const Right(null);
        }
      }

      return Left(CollaboratorNotFoundFailure());
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, bool>> checkUserExists(String email) async {
    try {
      final userRecord = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      return Right(userRecord.docs.isNotEmpty);
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, CollaboratorRole>> getCurrentUserRole(
      String projectId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        return Right(CollaboratorRole.viewer);
      }

      // Check if user is owner
      final project =
          await _firestore.collection('projects').doc(projectId).get();
      if (!project.exists) {
        return Left(ProjectNotFoundFailure());
      }

      if (project.data()?['user_id'] == userId) {
        return Right(CollaboratorRole.owner);
      }

      // Check collaborator role
      final collaboratorDoc = await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('collaborators')
          .doc(userId)
          .get();

      if (!collaboratorDoc.exists) {
        return Right(CollaboratorRole.viewer);
      }

      final roleStr = collaboratorDoc.data()?['role'] as String?;
      return Right(CollaboratorRole.values.firstWhere(
        (role) => role.name == roleStr,
        orElse: () => CollaboratorRole.viewer,
      ));
    } catch (e) {
      return Left(ServerFailure());
    }
  }
}
