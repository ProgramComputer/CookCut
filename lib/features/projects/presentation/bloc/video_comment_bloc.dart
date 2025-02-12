import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/video_comment.dart';
import '../../domain/repositories/video_comment_repository.dart';
import '../../../core/error/failures.dart';

// Events
abstract class VideoCommentEvent extends Equatable {
  const VideoCommentEvent();

  @override
  List<Object?> get props => [];
}

class StartWatchingComments extends VideoCommentEvent {
  final String projectId;
  final String assetId;

  const StartWatchingComments({
    required this.projectId,
    required this.assetId,
  });

  @override
  List<Object?> get props => [projectId, assetId];
}

class StopWatchingComments extends VideoCommentEvent {}

class AddComment extends VideoCommentEvent {
  final String projectId;
  final String assetId;
  final String text;
  final Duration timestamp;

  const AddComment({
    required this.projectId,
    required this.assetId,
    required this.text,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [projectId, assetId, text, timestamp];
}

class UpdateComment extends VideoCommentEvent {
  final String commentId;
  final String text;

  const UpdateComment({
    required this.commentId,
    required this.text,
  });

  @override
  List<Object?> get props => [commentId, text];
}

class DeleteComment extends VideoCommentEvent {
  final String commentId;

  const DeleteComment(this.commentId);

  @override
  List<Object?> get props => [commentId];
}

class _UpdateComments extends VideoCommentEvent {
  final List<VideoComment> comments;

  const _UpdateComments(this.comments);

  @override
  List<Object?> get props => [comments];
}

class _CommentError extends VideoCommentEvent {
  final String message;

  const _CommentError(this.message);

  @override
  List<Object?> get props => [message];
}

// State
enum VideoCommentStatus { initial, loading, success, error }

class VideoCommentState extends Equatable {
  final VideoCommentStatus status;
  final List<VideoComment> comments;
  final String? error;
  final bool isWatching;

  const VideoCommentState({
    this.status = VideoCommentStatus.initial,
    this.comments = const [],
    this.error,
    this.isWatching = false,
  });

  VideoCommentState copyWith({
    VideoCommentStatus? status,
    List<VideoComment>? comments,
    String? error,
    bool? isWatching,
  }) {
    return VideoCommentState(
      status: status ?? this.status,
      comments: comments ?? this.comments,
      error: error ?? this.error,
      isWatching: isWatching ?? this.isWatching,
    );
  }

  @override
  List<Object?> get props => [status, comments, error, isWatching];
}

// Bloc
class VideoCommentBloc extends Bloc<VideoCommentEvent, VideoCommentState> {
  final VideoCommentRepository _commentRepository;
  StreamSubscription<List<VideoComment>>? _commentSubscription;

  VideoCommentBloc({
    required VideoCommentRepository commentRepository,
  })  : _commentRepository = commentRepository,
        super(const VideoCommentState()) {
    on<StartWatchingComments>(_onStartWatchingComments);
    on<StopWatchingComments>(_onStopWatchingComments);
    on<AddComment>(_onAddComment);
    on<UpdateComment>(_onUpdateComment);
    on<DeleteComment>(_onDeleteComment);
    on<_UpdateComments>(_onUpdateComments);
    on<_CommentError>(_onCommentError);
  }

  Future<void> _onStartWatchingComments(
    StartWatchingComments event,
    Emitter<VideoCommentState> emit,
  ) async {
    _commentSubscription?.cancel();

    emit(state.copyWith(status: VideoCommentStatus.loading, isWatching: true));

    _commentSubscription = _commentRepository
        .watchAssetComments(event.projectId, event.assetId)
        .listen(
          (comments) => add(_UpdateComments(comments)),
          onError: (error) => add(_CommentError(error.toString())),
        );
  }

  Future<void> _onStopWatchingComments(
    StopWatchingComments event,
    Emitter<VideoCommentState> emit,
  ) async {
    await _commentSubscription?.cancel();
    _commentSubscription = null;
    emit(state.copyWith(isWatching: false));
  }

  Future<void> _onAddComment(
    AddComment event,
    Emitter<VideoCommentState> emit,
  ) async {
    emit(state.copyWith(status: VideoCommentStatus.loading));

    final result = await _commentRepository.addComment(
      projectId: event.projectId,
      assetId: event.assetId,
      text: event.text,
      timestamp: event.timestamp,
    );

    result.fold(
      (failure) => emit(state.copyWith(
        status: VideoCommentStatus.error,
        error: _mapFailureToMessage(failure),
      )),
      (comment) => emit(state.copyWith(
        status: VideoCommentStatus.success,
        comments: [...state.comments, comment],
      )),
    );
  }

  Future<void> _onUpdateComment(
    UpdateComment event,
    Emitter<VideoCommentState> emit,
  ) async {
    emit(state.copyWith(status: VideoCommentStatus.loading));

    final result = await _commentRepository.updateComment(
      commentId: event.commentId,
      text: event.text,
    );

    result.fold(
      (failure) => emit(state.copyWith(
        status: VideoCommentStatus.error,
        error: _mapFailureToMessage(failure),
      )),
      (updatedComment) {
        final updatedComments = state.comments.map((comment) {
          return comment.id == updatedComment.id ? updatedComment : comment;
        }).toList();
        emit(state.copyWith(
          status: VideoCommentStatus.success,
          comments: updatedComments,
        ));
      },
    );
  }

  Future<void> _onDeleteComment(
    DeleteComment event,
    Emitter<VideoCommentState> emit,
  ) async {
    emit(state.copyWith(status: VideoCommentStatus.loading));

    final result = await _commentRepository.deleteComment(event.commentId);

    result.fold(
      (failure) => emit(state.copyWith(
        status: VideoCommentStatus.error,
        error: _mapFailureToMessage(failure),
      )),
      (_) {
        final updatedComments = state.comments
            .where((comment) => comment.id != event.commentId)
            .toList();
        emit(state.copyWith(
          status: VideoCommentStatus.success,
          comments: updatedComments,
        ));
      },
    );
  }

  void _onUpdateComments(
    _UpdateComments event,
    Emitter<VideoCommentState> emit,
  ) {
    emit(state.copyWith(
      status: VideoCommentStatus.success,
      comments: event.comments,
    ));
  }

  void _onCommentError(
    _CommentError event,
    Emitter<VideoCommentState> emit,
  ) {
    emit(state.copyWith(
      status: VideoCommentStatus.error,
      error: event.message,
    ));
  }

  String _mapFailureToMessage(Failure failure) {
    switch (failure.runtimeType) {
      case ServerFailure:
        return 'Server error occurred';
      case InsufficientPermissionsFailure:
        return 'You do not have permission to perform this action';
      case UserNotFoundFailure:
        return 'User not found';
      case CommentNotFoundFailure:
        return 'Comment not found';
      default:
        return 'An unexpected error occurred';
    }
  }

  @override
  Future<void> close() {
    _commentSubscription?.cancel();
    return super.close();
  }

  void dispose() {
    close();
  }
}
