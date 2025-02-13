import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../domain/entities/project.dart';
import '../../domain/repositories/project_repository.dart';

// Events
abstract class ProjectsEvent extends Equatable {
  const ProjectsEvent();

  @override
  List<Object?> get props => [];
}

class LoadProjects extends ProjectsEvent {
  const LoadProjects();
}

class CreateProject extends ProjectsEvent {
  final String title;
  final String description;

  const CreateProject({
    required this.title,
    required this.description,
  });

  @override
  List<Object?> get props => [title, description];
}

class UpdateProject extends ProjectsEvent {
  final String projectId;
  final String? title;
  final String? description;

  const UpdateProject({
    required this.projectId,
    this.title,
    this.description,
  });

  @override
  List<Object?> get props => [projectId, title, description];
}

class DeleteProject extends ProjectsEvent {
  final String projectId;

  const DeleteProject({required this.projectId});

  @override
  List<Object?> get props => [projectId];
}

// States
enum ProjectsStatus { initial, loading, success, error }

class ProjectsState extends Equatable {
  final List<Project> projects;
  final ProjectsStatus status;
  final String? error;

  const ProjectsState({
    this.projects = const [],
    this.status = ProjectsStatus.initial,
    this.error,
  });

  ProjectsState copyWith({
    List<Project>? projects,
    ProjectsStatus? status,
    String? error,
  }) {
    return ProjectsState(
      projects: projects ?? this.projects,
      status: status ?? this.status,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [projects, status, error];
}

// Bloc
class ProjectsBloc extends Bloc<ProjectsEvent, ProjectsState> {
  final ProjectRepository _projectRepository;

  ProjectsBloc({
    required ProjectRepository projectRepository,
  })  : _projectRepository = projectRepository,
        super(const ProjectsState()) {
    on<LoadProjects>(_onLoadProjects);
    on<CreateProject>(_onCreateProject);
    on<UpdateProject>(_onUpdateProject);
    on<DeleteProject>(_onDeleteProject);
  }

  Future<void> _onLoadProjects(
    LoadProjects event,
    Emitter<ProjectsState> emit,
  ) async {
    emit(state.copyWith(status: ProjectsStatus.loading));
    try {
      final projects = await _projectRepository.getProjects();
      emit(state.copyWith(
        status: ProjectsStatus.success,
        projects: projects,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ProjectsStatus.error,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onCreateProject(
    CreateProject event,
    Emitter<ProjectsState> emit,
  ) async {
    emit(state.copyWith(status: ProjectsStatus.loading));
    try {
      final newProject = await _projectRepository.createProject(
        title: event.title,
        description: event.description,
      );

      final updatedProjects = [...state.projects, newProject];
      emit(state.copyWith(
        status: ProjectsStatus.success,
        projects: updatedProjects,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ProjectsStatus.error,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onUpdateProject(
    UpdateProject event,
    Emitter<ProjectsState> emit,
  ) async {
    emit(state.copyWith(status: ProjectsStatus.loading));
    try {
      final updatedProject = await _projectRepository.updateProject(
        projectId: event.projectId,
        title: event.title,
        description: event.description,
      );

      final updatedProjects = state.projects.map((project) {
        return project.id == event.projectId ? updatedProject : project;
      }).toList();

      emit(state.copyWith(
        status: ProjectsStatus.success,
        projects: updatedProjects,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ProjectsStatus.error,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onDeleteProject(
    DeleteProject event,
    Emitter<ProjectsState> emit,
  ) async {
    emit(state.copyWith(status: ProjectsStatus.loading));
    try {
      await _projectRepository.deleteProject(event.projectId);
      final updatedProjects = state.projects
          .where((project) => project.id != event.projectId)
          .toList();
      emit(state.copyWith(
        status: ProjectsStatus.success,
        projects: updatedProjects,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ProjectsStatus.error,
        error: e.toString(),
      ));
    }
  }
}
