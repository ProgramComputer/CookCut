import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/edit_session.dart';
import '../../domain/repositories/edit_session_repository.dart';
import '../../../core/error/failures.dart';

// Events
abstract class EditSessionEvent extends Equatable {
  const EditSessionEvent();

  @override
  List<Object?> get props => [];
}

class StartWatchingSession extends EditSessionEvent {
  final String projectId;

  const StartWatchingSession(this.projectId);

  @override
  List<Object?> get props => [projectId];
}

class StopWatchingSession extends EditSessionEvent {}

class StartEditing extends EditSessionEvent {
  final String projectId;

  const StartEditing(this.projectId);

  @override
  List<Object?> get props => [projectId];
}

class StopEditing extends EditSessionEvent {
  final String sessionId;

  const StopEditing(this.sessionId);

  @override
  List<Object?> get props => [sessionId];
}

class KeepAlive extends EditSessionEvent {
  final String sessionId;

  const KeepAlive(this.sessionId);

  @override
  List<Object?> get props => [sessionId];
}

class _UpdateSession extends EditSessionEvent {
  final EditSession? session;

  const _UpdateSession(this.session);

  @override
  List<Object?> get props => [session];
}

class _SessionError extends EditSessionEvent {
  final String message;

  const _SessionError(this.message);

  @override
  List<Object?> get props => [message];
}

// States
enum EditSessionStatus { initial, loading, success, error }

class EditSessionState extends Equatable {
  final EditSessionStatus status;
  final EditSession? currentSession;
  final bool canEdit;
  final String? error;
  final bool isWatching;

  const EditSessionState({
    this.status = EditSessionStatus.initial,
    this.currentSession,
    this.canEdit = false,
    this.error,
    this.isWatching = false,
  });

  bool get isEditing => currentSession != null;
  bool get isCurrentUserEditing =>
      currentSession?.userId == currentSession?.userId;

  EditSessionState copyWith({
    EditSessionStatus? status,
    EditSession? currentSession,
    bool? canEdit,
    String? error,
    bool? isWatching,
  }) {
    return EditSessionState(
      status: status ?? this.status,
      currentSession: currentSession ?? this.currentSession,
      canEdit: canEdit ?? this.canEdit,
      error: error ?? this.error,
      isWatching: isWatching ?? this.isWatching,
    );
  }

  @override
  List<Object?> get props => [
        status,
        currentSession,
        canEdit,
        error,
        isWatching,
      ];
}

// Bloc
class EditSessionBloc extends Bloc<EditSessionEvent, EditSessionState> {
  final EditSessionRepository _editSessionRepository;
  StreamSubscription<EditSession?>? _sessionSubscription;
  Timer? _keepAliveTimer;
  static const keepAliveInterval = Duration(minutes: 1);

  EditSessionBloc({
    required EditSessionRepository editSessionRepository,
  })  : _editSessionRepository = editSessionRepository,
        super(const EditSessionState()) {
    on<StartWatchingSession>(_onStartWatchingSession);
    on<StopWatchingSession>(_onStopWatchingSession);
    on<StartEditing>(_onStartEditing);
    on<StopEditing>(_onStopEditing);
    on<KeepAlive>(_onKeepAlive);
    on<_UpdateSession>(_onUpdateSession);
    on<_SessionError>(_onSessionError);
  }

  Future<void> _onStartWatchingSession(
    StartWatchingSession event,
    Emitter<EditSessionState> emit,
  ) async {
    _sessionSubscription?.cancel();

    emit(state.copyWith(status: EditSessionStatus.loading, isWatching: true));

    // Check if user can edit
    final canEditResult = await _editSessionRepository.canEdit(event.projectId);
    final canEdit = canEditResult.fold(
      (failure) => false,
      (canEdit) => canEdit,
    );

    emit(state.copyWith(canEdit: canEdit));

    _sessionSubscription =
        _editSessionRepository.watchCurrentSession(event.projectId).listen(
              (session) => add(_UpdateSession(session)),
              onError: (error) => add(_SessionError(error.toString())),
            );
  }

  Future<void> _onStopWatchingSession(
    StopWatchingSession event,
    Emitter<EditSessionState> emit,
  ) async {
    await _sessionSubscription?.cancel();
    _sessionSubscription = null;
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
    emit(state.copyWith(isWatching: false));
  }

  Future<void> _onStartEditing(
    StartEditing event,
    Emitter<EditSessionState> emit,
  ) async {
    if (!state.canEdit) {
      emit(state.copyWith(
        status: EditSessionStatus.error,
        error: 'You do not have permission to edit this project',
      ));
      return;
    }

    emit(state.copyWith(status: EditSessionStatus.loading));

    final result = await _editSessionRepository.startSession(event.projectId);

    result.fold(
      (failure) => emit(state.copyWith(
        status: EditSessionStatus.error,
        error: _mapFailureToMessage(failure),
      )),
      (session) {
        // Start keep-alive timer
        _keepAliveTimer?.cancel();
        _keepAliveTimer = Timer.periodic(keepAliveInterval, (timer) {
          if (session.id.isNotEmpty) {
            add(KeepAlive(session.id));
          }
        });

        emit(state.copyWith(
          status: EditSessionStatus.success,
          currentSession: session,
        ));
      },
    );
  }

  Future<void> _onStopEditing(
    StopEditing event,
    Emitter<EditSessionState> emit,
  ) async {
    emit(state.copyWith(status: EditSessionStatus.loading));

    final result = await _editSessionRepository.endSession(event.sessionId);

    result.fold(
      (failure) => emit(state.copyWith(
        status: EditSessionStatus.error,
        error: _mapFailureToMessage(failure),
      )),
      (_) {
        _keepAliveTimer?.cancel();
        _keepAliveTimer = null;

        emit(state.copyWith(
          status: EditSessionStatus.success,
          currentSession: null,
        ));
      },
    );
  }

  Future<void> _onKeepAlive(
    KeepAlive event,
    Emitter<EditSessionState> emit,
  ) async {
    final result =
        await _editSessionRepository.keepSessionAlive(event.sessionId);

    result.fold(
      (failure) {
        // If we can't keep the session alive, stop editing
        _keepAliveTimer?.cancel();
        _keepAliveTimer = null;
        emit(state.copyWith(
          status: EditSessionStatus.error,
          error: _mapFailureToMessage(failure),
          currentSession: null,
        ));
      },
      (_) => null, // Do nothing on success
    );
  }

  void _onUpdateSession(
    _UpdateSession event,
    Emitter<EditSessionState> emit,
  ) {
    emit(state.copyWith(
      status: EditSessionStatus.success,
      currentSession: event.session,
    ));
  }

  void _onSessionError(
    _SessionError event,
    Emitter<EditSessionState> emit,
  ) {
    emit(state.copyWith(
      status: EditSessionStatus.error,
      error: event.message,
    ));
  }

  String _mapFailureToMessage(dynamic failure) {
    switch (failure.runtimeType) {
      case SessionInUseFailure:
        return 'Project is currently being edited by another user';
      case SessionNotFoundFailure:
        return 'Edit session not found';
      case InsufficientPermissionsFailure:
        return 'You do not have permission to perform this action';
      case ProjectNotFoundFailure:
        return 'Project not found';
      default:
        return 'An unexpected error occurred';
    }
  }

  @override
  Future<void> close() {
    _sessionSubscription?.cancel();
    _keepAliveTimer?.cancel();
    return super.close();
  }
}
