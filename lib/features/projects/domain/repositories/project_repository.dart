import '../entities/project.dart';

abstract class ProjectRepository {
  Future<List<Project>> getProjects();

  Future<Project> createProject({
    required String title,
    required String description,
  });

  Future<Project> updateProject({
    required String projectId,
    String? title,
    String? description,
  });

  Future<void> deleteProject(String projectId);
}
