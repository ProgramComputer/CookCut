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
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              return Collaborator(
                id: doc.id, // This will be the user's UID
                projectId: projectId,
                userId: doc.id, // Using doc.id since it's the user's UID
                email: data['email'] as String?,
                displayName: data['displayName'] as String?,
                photoUrl: data['photoUrl'] as String?,
                role: CollaboratorRole.values.firstWhere(
                  (role) => role.name == data['role'],
                  orElse: () => CollaboratorRole.viewer,
                ),
                addedAt: (data['addedAt'] as Timestamp).toDate(),
              );
            }).toList());
  }

  @override
  Future<Either<Failure, Collaborator>> addCollaborator({
    required String projectId,
    required String email,
    required CollaboratorRole role,
  }) async {
    try {
      // 1. Verify current user is project owner
      if (!await _isProjectOwner(projectId)) {
        return Left(InsufficientPermissionsFailure());
      }

      // 2. Check if user exists in Firebase Auth
      final userRecord = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (userRecord.docs.isEmpty) {
        return Left(UserNotFoundFailure());
      }

      final userData = userRecord.docs.first.data();
      final userId = userRecord.docs.first.id;

      // 3. Check if user is already a collaborator
      final collaboratorDoc = await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('collaborators')
          .doc(userId) // Using user's UID as document ID
          .get();

      if (collaboratorDoc.exists) {
        return Left(CollaboratorAlreadyExistsFailure());
      }

      // 4. Add collaborator using user's UID as document ID
      final collaborator = Collaborator(
        id: userId,
        projectId: projectId,
        userId: userId,
        email: email,
        displayName: userData['displayName'] as String?,
        photoUrl: userData['photoUrl'] as String?,
        role: role,
        addedAt: DateTime.now(),
      );

      await _firestore
          .collection('projects')
          .doc(projectId)
          .collection('collaborators')
          .doc(userId)
          .set({
        'email': collaborator.email,
        'displayName': collaborator.displayName,
        'photoUrl': collaborator.photoUrl,
        'role': collaborator.role.name,
        'addedAt': Timestamp.fromDate(collaborator.addedAt),
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
      // Find the project this collaborator belongs to
      final collaboratorQuery = await _firestore
          .collectionGroup('collaborators')
          .where(FieldPath.documentId, isEqualTo: collaboratorId)
          .limit(1)
          .get();

      if (collaboratorQuery.docs.isEmpty) {
        return Left(CollaboratorNotFoundFailure());
      }

      final collaboratorDoc = collaboratorQuery.docs.first;
      final projectId = collaboratorDoc.reference.parent.parent!.id;

      // Verify current user is project owner
      if (!await _isProjectOwner(projectId)) {
        return Left(InsufficientPermissionsFailure());
      }

      final data = collaboratorDoc.data();
      await collaboratorDoc.reference.update({'role': newRole.name});

      return Right(Collaborator(
        id: collaboratorDoc.id,
        projectId: projectId,
        userId: collaboratorDoc.id,
        email: data['email'] as String?,
        displayName: data['displayName'] as String?,
        photoUrl: data['photoUrl'] as String?,
        role: newRole,
        addedAt: (data['addedAt'] as Timestamp).toDate(),
      ));
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, void>> removeCollaborator(
      String collaboratorId) async {
    try {
      final collaboratorQuery = await _firestore
          .collectionGroup('collaborators')
          .where(FieldPath.documentId, isEqualTo: collaboratorId)
          .limit(1)
          .get();

      if (collaboratorQuery.docs.isEmpty) {
        return Left(CollaboratorNotFoundFailure());
      }

      final collaboratorDoc = collaboratorQuery.docs.first;
      final projectId = collaboratorDoc.reference.parent.parent!.id;

      // Verify current user is project owner
      if (!await _isProjectOwner(projectId)) {
        return Left(InsufficientPermissionsFailure());
      }

      await collaboratorDoc.reference.delete();
      return const Right(null);
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
}
