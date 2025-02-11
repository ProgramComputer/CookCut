import 'package:dartz/dartz.dart';
import '../entities/edit_session.dart';
import '../../../core/error/failures.dart';

abstract class EditSessionRepository {
  /// Start an edit session for a project
  Future<Either<Failure, EditSession>> startSession(String projectId);

  /// End the current edit session
  Future<Either<Failure, void>> endSession(String sessionId);

  /// Update the last activity timestamp to keep the session alive
  Future<Either<Failure, void>> keepSessionAlive(String sessionId);

  /// Get the current active session for a project
  Future<Either<Failure, EditSession?>> getCurrentSession(String projectId);

  /// Watch the current active session for a project
  Stream<EditSession?> watchCurrentSession(String projectId);

  /// Check if the current user can edit the project
  Future<Either<Failure, bool>> canEdit(String projectId);
}
