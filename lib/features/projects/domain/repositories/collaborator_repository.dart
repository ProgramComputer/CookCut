import 'package:dartz/dartz.dart';
import '../entities/collaborator.dart';
import '../entities/collaborator_role.dart';
import '../../../core/error/failures.dart';

abstract class CollaboratorRepository {
  /// Stream of collaborators for a project
  Stream<List<Collaborator>> watchCollaborators(String projectId);

  /// Add a collaborator to a project
  Future<Either<Failure, Collaborator>> addCollaborator({
    required String projectId,
    required String email,
    required CollaboratorRole role,
  });

  /// Update a collaborator's role
  Future<Either<Failure, Collaborator>> updateCollaboratorRole({
    required String collaboratorId,
    required CollaboratorRole newRole,
  });

  /// Remove a collaborator from a project
  Future<Either<Failure, void>> removeCollaborator(String collaboratorId);

  /// Check if a user exists by email
  Future<Either<Failure, bool>> checkUserExists(String email);

  /// Get the current user's role in a project
  Future<Either<Failure, CollaboratorRole>> getCurrentUserRole(
      String projectId);
}
