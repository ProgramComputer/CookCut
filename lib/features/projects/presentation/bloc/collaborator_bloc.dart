import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/collaborator.dart';
import '../../domain/entities/collaborator_role.dart';
import '../../domain/repositories/collaborator_repository.dart';
import '../../../core/error/failures.dart';

// Events
abstract class CollaboratorEvent extends Equatable {
  const CollaboratorEvent();

  @override
  List<Object?> get props => [];
}

class StartWatchingCollaborators extends CollaboratorEvent {
  final String projectId;

  const StartWatchingCollaborators(this.projectId);

  @override
  List<Object?> get props => [projectId];
}

class StopWatchingCollaborators extends CollaboratorEvent {}

class AddCollaborator extends CollaboratorEvent {
  final String projectId;
  final String email;
  final CollaboratorRole role;

  const AddCollaborator({
    required this.projectId,
    required this.email,
    required this.role,
  });

  @override
  List<Object?> get props => [projectId, email, role];
}

class UpdateCollaboratorRole extends CollaboratorEvent {
  final String collaboratorId;
  final CollaboratorRole newRole;

  const UpdateCollaboratorRole({
    required this.collaboratorId,
    required this.newRole,
  });

  @override
  List<Object?> get props => [collaboratorId, newRole];
}

class RemoveCollaborator extends CollaboratorEvent {
  final String collaboratorId;

  const RemoveCollaborator({required this.collaboratorId});

  @override
  List<Object?> get props => [collaboratorId];
}

class _UpdateCollaborators extends CollaboratorEvent {
  final List<Collaborator> collaborators;

  const _UpdateCollaborators(this.collaborators);

  @override
  List<Object?> get props => [collaborators];
}

class _CollaboratorError extends CollaboratorEvent {
  final String message;

  const _CollaboratorError(this.message);

  @override
  List<Object?> get props => [message];
}

// States
enum CollaboratorStatus { initial, loading, success, error }

class CollaboratorState extends Equatable {
  final CollaboratorStatus status;
  final List<Collaborator> collaborators;
  final CollaboratorRole? currentUserRole;
  final String? error;
  final bool isWatching;

  const CollaboratorState({
    this.status = CollaboratorStatus.initial,
    this.collaborators = const [],
    this.currentUserRole,
    this.error,
    this.isWatching = false,
  });

  CollaboratorState copyWith({
    CollaboratorStatus? status,
    List<Collaborator>? collaborators,
    CollaboratorRole? currentUserRole,
    String? error,
    bool? isWatching,
  }) {
    return CollaboratorState(
      status: status ?? this.status,
      collaborators: collaborators ?? this.collaborators,
      currentUserRole: currentUserRole ?? this.currentUserRole,
      error: error ?? this.error,
      isWatching: isWatching ?? this.isWatching,
    );
  }

  @override
  List<Object?> get props => [
        status,
        collaborators,
        currentUserRole,
        error,
        isWatching,
      ];
}

// Bloc
class CollaboratorBloc extends Bloc<CollaboratorEvent, CollaboratorState> {
  final CollaboratorRepository _collaboratorRepository;
  StreamSubscription<List<Collaborator>>? _collaboratorSubscription;

  CollaboratorBloc({
    required CollaboratorRepository collaboratorRepository,
  })  : _collaboratorRepository = collaboratorRepository,
        super(const CollaboratorState()) {
    on<StartWatchingCollaborators>(_onStartWatchingCollaborators);
    on<StopWatchingCollaborators>(_onStopWatchingCollaborators);
    on<AddCollaborator>(_onAddCollaborator);
    on<UpdateCollaboratorRole>(_onUpdateCollaboratorRole);
    on<RemoveCollaborator>(_onRemoveCollaborator);
    on<_UpdateCollaborators>(_onUpdateCollaborators);
    on<_CollaboratorError>(_onCollaboratorError);
  }

  Future<void> _onStartWatchingCollaborators(
    StartWatchingCollaborators event,
    Emitter<CollaboratorState> emit,
  ) async {
    _collaboratorSubscription?.cancel();

    emit(state.copyWith(status: CollaboratorStatus.loading, isWatching: true));

    // Get current user role
    final roleResult =
        await _collaboratorRepository.getCurrentUserRole(event.projectId);
    final currentRole = roleResult.fold(
      (failure) => CollaboratorRole.viewer,
      (role) => role,
    );

    emit(state.copyWith(currentUserRole: currentRole));

    _collaboratorSubscription =
        _collaboratorRepository.watchCollaborators(event.projectId).listen(
              (collaborators) => add(_UpdateCollaborators(collaborators)),
              onError: (error) => add(_CollaboratorError(error.toString())),
            );
  }

  Future<void> _onStopWatchingCollaborators(
    StopWatchingCollaborators event,
    Emitter<CollaboratorState> emit,
  ) async {
    await _collaboratorSubscription?.cancel();
    _collaboratorSubscription = null;
    emit(state.copyWith(isWatching: false));
  }

  Future<void> _onAddCollaborator(
    AddCollaborator event,
    Emitter<CollaboratorState> emit,
  ) async {
    emit(state.copyWith(status: CollaboratorStatus.loading));

    final result = await _collaboratorRepository.addCollaborator(
      projectId: event.projectId,
      email: event.email,
      role: event.role,
    );

    result.fold(
      (failure) => emit(state.copyWith(
        status: CollaboratorStatus.error,
        error: _mapFailureToMessage(failure),
      )),
      (collaborator) => emit(state.copyWith(
        status: CollaboratorStatus.success,
        collaborators: [...state.collaborators, collaborator],
      )),
    );
  }

  Future<void> _onUpdateCollaboratorRole(
    UpdateCollaboratorRole event,
    Emitter<CollaboratorState> emit,
  ) async {
    emit(state.copyWith(status: CollaboratorStatus.loading));

    final result = await _collaboratorRepository.updateCollaboratorRole(
      collaboratorId: event.collaboratorId,
      newRole: event.newRole,
    );

    result.fold(
      (failure) => emit(state.copyWith(
        status: CollaboratorStatus.error,
        error: _mapFailureToMessage(failure),
      )),
      (collaborator) {
        final updatedCollaborators = state.collaborators
            .map((c) {
              return c.id == collaborator.id ? collaborator : c;
            })
            .toList()
            .cast<Collaborator>();

        emit(state.copyWith(
          status: CollaboratorStatus.success,
          collaborators: updatedCollaborators,
        ));
      },
    );
  }

  Future<void> _onRemoveCollaborator(
    RemoveCollaborator event,
    Emitter<CollaboratorState> emit,
  ) async {
    emit(state.copyWith(status: CollaboratorStatus.loading));

    final result = await _collaboratorRepository.removeCollaborator(
      event.collaboratorId,
    );

    result.fold(
      (failure) => emit(state.copyWith(
        status: CollaboratorStatus.error,
        error: _mapFailureToMessage(failure),
      )),
      (_) {
        final updatedCollaborators = state.collaborators
            .where((c) => c.id != event.collaboratorId)
            .toList()
            .cast<Collaborator>();

        emit(state.copyWith(
          status: CollaboratorStatus.success,
          collaborators: updatedCollaborators,
        ));
      },
    );
  }

  void _onUpdateCollaborators(
    _UpdateCollaborators event,
    Emitter<CollaboratorState> emit,
  ) {
    emit(state.copyWith(
      status: CollaboratorStatus.success,
      collaborators: event.collaborators,
    ));
  }

  void _onCollaboratorError(
    _CollaboratorError event,
    Emitter<CollaboratorState> emit,
  ) {
    emit(state.copyWith(
      status: CollaboratorStatus.error,
      error: event.message,
    ));
  }

  String _mapFailureToMessage(Failure failure) {
    switch (failure.runtimeType) {
      case UserNotFoundFailure:
        return 'User not found. Please check the email address.';
      case CollaboratorAlreadyExistsFailure:
        return 'This user is already a collaborator on this project.';
      case InsufficientPermissionsFailure:
        return 'You do not have permission to manage collaborators.';
      case ProjectNotFoundFailure:
        return 'Project not found.';
      default:
        return 'An unexpected error occurred. Please try again.';
    }
  }

  @override
  Future<void> close() {
    _collaboratorSubscription?.cancel();
    return super.close();
  }
}
