import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/media_asset.dart';
import '../../domain/repositories/media_repository.dart';

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

  const UploadMedia({
    required this.projectId,
    required this.filePath,
    required this.type,
    this.metadata = const {},
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
enum MediaStatus { initial, loading, success, error }

class MediaState extends Equatable {
  final List<MediaAsset> assets;
  final MediaStatus status;
  final String? error;
  final double? uploadProgress;

  const MediaState({
    this.assets = const [],
    this.status = MediaStatus.initial,
    this.error,
    this.uploadProgress,
  });

  MediaState copyWith({
    List<MediaAsset>? assets,
    MediaStatus? status,
    String? error,
    double? uploadProgress,
  }) {
    return MediaState(
      assets: assets ?? this.assets,
      status: status ?? this.status,
      error: error ?? this.error,
      uploadProgress: uploadProgress ?? this.uploadProgress,
    );
  }

  @override
  List<Object?> get props => [assets, status, error, uploadProgress];
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
    emit(state.copyWith(status: MediaStatus.loading));
    try {
      final assets = await _mediaRepository.getProjectMedia(event.projectId);
      emit(state.copyWith(
        status: MediaStatus.success,
        assets: assets,
      ));
    } catch (e) {
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
    emit(state.copyWith(
      status: MediaStatus.loading,
      uploadProgress: 0,
    ));
    try {
      final asset = await _mediaRepository.uploadMedia(
        projectId: event.projectId,
        filePath: event.filePath,
        type: event.type,
        metadata: event.metadata,
      );

      final updatedAssets = [...state.assets, asset];
      emit(state.copyWith(
        status: MediaStatus.success,
        assets: updatedAssets,
        uploadProgress: null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: MediaStatus.error,
        error: e.toString(),
        uploadProgress: null,
      ));
    }
  }

  Future<void> _onDeleteMedia(
    DeleteMedia event,
    Emitter<MediaState> emit,
  ) async {
    emit(state.copyWith(status: MediaStatus.loading));
    try {
      await _mediaRepository.deleteMedia(event.asset);
      final updatedAssets =
          state.assets.where((asset) => asset.id != event.asset.id).toList();
      emit(state.copyWith(
        status: MediaStatus.success,
        assets: updatedAssets,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: MediaStatus.error,
        error: e.toString(),
      ));
    }
  }
}
