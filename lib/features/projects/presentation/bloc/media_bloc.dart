import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'dart:developer' as developer;
import 'dart:async';
import '../../domain/entities/media_asset.dart';
import '../../domain/repositories/media_repository.dart';
import '../../domain/entities/video_processing_config.dart';

// Events
abstract class MediaEvent extends Equatable {
  const MediaEvent();

  @override
  List<Object?> get props => [];
}

class LoadProjectMedia extends MediaEvent {
  final String projectId;

  const LoadProjectMedia(this.projectId);

  @override
  List<Object?> get props => [projectId];
}

class UploadMedia extends MediaEvent {
  final String projectId;
  final String filePath;
  final MediaType type;
  final Map<String, dynamic> metadata;
  final StreamController<double>? progressController;

  const UploadMedia({
    required this.projectId,
    required this.filePath,
    required this.type,
    this.metadata = const {},
    this.progressController,
  });

  @override
  List<Object?> get props => [projectId, filePath, type, metadata];
}

class DeleteMedia extends MediaEvent {
  final MediaAsset asset;

  const DeleteMedia(this.asset);

  @override
  List<Object?> get props => [asset];
}

// States
enum MediaStatus { initial, loading, processing, success, error }

class MediaState extends Equatable {
  final MediaStatus status;
  final List<MediaAsset> assets;
  final String? error;
  final double? processingProgress;

  const MediaState({
    this.status = MediaStatus.initial,
    this.assets = const [],
    this.error,
    this.processingProgress,
  });

  MediaState copyWith({
    MediaStatus? status,
    List<MediaAsset>? assets,
    String? error,
    double? processingProgress,
  }) {
    return MediaState(
      status: status ?? this.status,
      assets: assets ?? this.assets,
      error: error,
      processingProgress: processingProgress ?? this.processingProgress,
    );
  }

  @override
  List<Object?> get props => [status, assets, error, processingProgress];
}

// Bloc
class MediaBloc extends Bloc<MediaEvent, MediaState> {
  final MediaRepository _mediaRepository;

  MediaBloc({
    required MediaRepository mediaRepository,
  })  : _mediaRepository = mediaRepository,
        super(const MediaState()) {
    on<LoadProjectMedia>(_onLoadProjectMedia);
    on<UploadMedia>(_onUploadMedia);
    on<DeleteMedia>(_onDeleteMedia);
  }

  Future<void> _onLoadProjectMedia(
    LoadProjectMedia event,
    Emitter<MediaState> emit,
  ) async {
    developer.log(
      'Loading project media',
      name: 'MediaBloc',
      error: {'projectId': event.projectId},
    );
    emit(state.copyWith(status: MediaStatus.loading));
    try {
      final assets = await _mediaRepository.getProjectMedia(event.projectId);
      developer.log(
        'Project media loaded successfully',
        name: 'MediaBloc',
        error: {'projectId': event.projectId, 'assetCount': assets.length},
      );
      emit(state.copyWith(
        status: MediaStatus.success,
        assets: assets,
      ));
    } catch (e, stackTrace) {
      developer.log(
        'Error loading project media',
        error: e,
        stackTrace: stackTrace,
        name: 'MediaBloc',
      );
      emit(state.copyWith(
        status: MediaStatus.error,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onUploadMedia(
    UploadMedia event,
    Emitter<MediaState> emit,
  ) async {
    developer.log(
      'Starting media upload',
      name: 'MediaBloc',
      error: {
        'projectId': event.projectId,
        'filePath': event.filePath,
        'type': event.type.toString(),
      },
    );

    if (event.type == MediaType.audio) {
      emit(state.copyWith(status: MediaStatus.loading));
    } else {
      emit(state.copyWith(
        status: MediaStatus.processing,
        processingProgress: 0.0,
      ));

      // Listen to processing progress if available
      if (event.progressController != null) {
        event.progressController!.stream.listen(
          (progress) {
            emit(state.copyWith(
              status: MediaStatus.processing,
              processingProgress: progress,
            ));
          },
          onError: (error) {
            emit(state.copyWith(
              status: MediaStatus.error,
              error: 'Processing error: $error',
            ));
          },
        );
      }
    }

    try {
      final asset = await _mediaRepository.uploadMedia(
        projectId: event.projectId,
        filePath: event.filePath,
        type: event.type,
        metadata: event.metadata,
        progressController: event.progressController,
      );

      developer.log(
        'Media upload successful',
        name: 'MediaBloc',
        error: {
          'projectId': event.projectId,
          'assetId': asset.id,
          'fileUrl': asset.fileUrl,
        },
      );

      final updatedAssets = [...state.assets, asset];
      emit(state.copyWith(
        status: MediaStatus.success,
        assets: updatedAssets,
        processingProgress: null,
      ));
    } catch (e, stackTrace) {
      developer.log(
        'Error uploading media',
        error: e,
        stackTrace: stackTrace,
        name: 'MediaBloc',
      );
      emit(state.copyWith(
        status: MediaStatus.error,
        error: e.toString(),
        processingProgress: null,
      ));
    }
  }

  Future<void> _onDeleteMedia(
    DeleteMedia event,
    Emitter<MediaState> emit,
  ) async {
    developer.log(
      'Deleting media',
      name: 'MediaBloc',
      error: {'assetId': event.asset.id, 'projectId': event.asset.projectId},
    );
    emit(state.copyWith(status: MediaStatus.loading));
    try {
      await _mediaRepository.deleteMedia(event.asset);
      final updatedAssets =
          state.assets.where((asset) => asset.id != event.asset.id).toList();
      developer.log(
        'Media deleted successfully',
        name: 'MediaBloc',
        error: {'assetId': event.asset.id},
      );
      emit(state.copyWith(
        status: MediaStatus.success,
        assets: updatedAssets,
      ));
    } catch (e, stackTrace) {
      developer.log(
        'Error deleting media',
        error: e,
        stackTrace: stackTrace,
        name: 'MediaBloc',
      );
      emit(state.copyWith(
        status: MediaStatus.error,
        error: e.toString(),
      ));
    }
  }
}
