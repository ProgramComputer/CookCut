import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  @override
  List<Object?> get props => [];
}

class ServerFailure extends Failure {}

class UserNotFoundFailure extends Failure {}

class CollaboratorAlreadyExistsFailure extends Failure {}

class CollaboratorNotFoundFailure extends Failure {}

class InsufficientPermissionsFailure extends Failure {}

class SessionInUseFailure extends Failure {}

class SessionNotFoundFailure extends Failure {}

class ProjectNotFoundFailure extends Failure {}

class CommentNotFoundFailure extends Failure {}
