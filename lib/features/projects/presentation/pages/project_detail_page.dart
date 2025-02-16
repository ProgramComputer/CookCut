import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../domain/entities/project.dart';
import '../../domain/entities/media_asset.dart';
import '../../domain/entities/collaborator.dart';
import '../../domain/entities/collaborator_role.dart';
import '../bloc/media_bloc.dart';
import '../bloc/collaborator_bloc.dart';
import '../bloc/edit_session_bloc.dart';
import '../widgets/upload_media_dialog.dart';
import '../widgets/media_import_widget.dart';
import '../widgets/media_grid.dart';
import '../widgets/collaborator_bottom_sheet.dart';
import '../widgets/edit_status_banner.dart';
import '../widgets/edit_project_dialog.dart';
import '../../../../core/presentation/utils/snackbar_utils.dart';
import '../../data/repositories/media_repository_impl.dart';
import '../../data/repositories/collaborator_repository_impl.dart';
import '../../data/repositories/edit_session_repository_impl.dart';
import '../../data/services/media_processing_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../bloc/analytics_bloc.dart';
import '../pages/analytics_page.dart';
import '../../domain/repositories/analytics_repository.dart';
import '../../data/repositories/analytics_repository_impl.dart';
import '../bloc/projects_bloc.dart';
import '../../data/repositories/project_repository_impl.dart';
import '../widgets/ai_chat_interface.dart';

class ProjectDetailPage extends StatelessWidget {
  final String projectId;
  final Project project;

  const ProjectDetailPage({
    super.key,
    required this.projectId,
    required this.project,
  });

  void _showUploadDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => UploadMediaDialog(projectId: projectId),
    );
  }

  void _showCollaboratorsSheet(BuildContext context) {
    final collaboratorBloc = context.read<CollaboratorBloc>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (context) => BlocProvider.value(
        value: collaboratorBloc,
        child: BlocBuilder<CollaboratorBloc, CollaboratorState>(
          builder: (context, state) {
            if (state.status == CollaboratorStatus.loading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state.status == CollaboratorStatus.error) {
              return Center(
                child: Text(
                  state.error ?? 'An error occurred',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              );
            }

            return CollaboratorBottomSheet(
              projectId: projectId,
              collaborators: state.collaborators,
              currentUserRole: state.currentUserRole ?? CollaboratorRole.viewer,
              onInvite: (email) {
                context.read<CollaboratorBloc>().add(
                      AddCollaborator(
                        projectId: projectId,
                        email: email,
                        role: CollaboratorRole.viewer,
                      ),
                    );
              },
              onRoleChange: (collaboratorId, newRole) {
                context.read<CollaboratorBloc>().add(
                      UpdateCollaboratorRole(
                        collaboratorId: collaboratorId,
                        newRole: newRole,
                      ),
                    );
              },
              onRemove: (collaboratorId) {
                context.read<CollaboratorBloc>().add(
                      RemoveCollaborator(collaboratorId: collaboratorId),
                    );
              },
            );
          },
        ),
      ),
    );
  }

  void _showEditProjectDialog(BuildContext context) {
    final projectsBloc = context.read<ProjectsBloc>();
    showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: projectsBloc,
        child: EditProjectDialog(project: project),
      ),
    );
  }

  void _showChatInterface(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      enableDrag: true,
      isDismissible: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        snap: true,
        snapSizes: const [0.6, 0.9],
        builder: (context, scrollController) => AIChatInterface(
          projectId: projectId,
          onClose: () => Navigator.of(context).pop(),
          onTimestampTap: (timestamp) {
            // Handle project-wide timestamp navigation
            // This could open the relevant media asset at the specified timestamp
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaProcessingService = MediaProcessingService(
      supabase: Supabase.instance.client,
    );

    final mediaRepository = MediaRepositoryImpl(
      firestore: FirebaseFirestore.instance,
      supabase: Supabase.instance.client,
      auth: FirebaseAuth.instance,
      mediaProcessingService: mediaProcessingService,
    );

    final collaboratorRepository = CollaboratorRepositoryImpl(
      firestore: FirebaseFirestore.instance,
      auth: FirebaseAuth.instance,
    );

    final editSessionRepository = EditSessionRepositoryImpl(
      firestore: FirebaseFirestore.instance,
      auth: FirebaseAuth.instance,
    );

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => MediaBloc(
            mediaRepository: mediaRepository,
          )..add(StartWatchingProjectMedia(projectId)),
        ),
        BlocProvider(
          create: (context) => CollaboratorBloc(
            collaboratorRepository: collaboratorRepository,
          )..add(StartWatchingCollaborators(projectId)),
        ),
        BlocProvider(
          create: (context) => EditSessionBloc(
            editSessionRepository: editSessionRepository,
          )..add(StartWatchingSession(projectId)),
        ),
        BlocProvider(
          create: (context) => AnalyticsBloc(
            analyticsRepository: AnalyticsRepositoryImpl(
              firestore: FirebaseFirestore.instance,
              auth: FirebaseAuth.instance,
            ),
          ),
        ),
        BlocProvider(
          create: (context) => ProjectsBloc(
            projectRepository: ProjectRepositoryImpl(
              firestore: FirebaseFirestore.instance,
              auth: FirebaseAuth.instance,
            ),
          )..add(const LoadProjects()),
        ),
      ],
      child: Builder(
        builder: (context) => BlocListener<ProjectsBloc, ProjectsState>(
          listener: (context, state) {
            if (state.status == ProjectsStatus.success) {
              // Find the updated project in the state
              final updatedProject = state.projects.firstWhere(
                (p) => p.id == projectId,
                orElse: () => project,
              );

              // Update the app bar title
              if (updatedProject.title != project.title) {
                context.go('/projects/${updatedProject.id}',
                    extra: updatedProject);
              }
            }
          },
          child: Scaffold(
            appBar: AppBar(
              title: BlocBuilder<ProjectsBloc, ProjectsState>(
                builder: (context, state) {
                  print('ProjectsBloc State: ${state.status}');
                  print('Projects in state: ${state.projects.length}');
                  print('Looking for project ID: $projectId');
                  print(
                      'Projects IDs in state: ${state.projects.map((p) => p.id).join(', ')}');

                  final currentProject = state.projects.firstWhere(
                    (p) => p.id == projectId,
                    orElse: () {
                      print(
                          'Project not found in state, using fallback project');
                      return project;
                    },
                  );
                  print('Current project title: ${currentProject.title}');
                  return Text(
                    currentProject.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onBackground,
                        ),
                  );
                },
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.people_outline),
                  tooltip: 'Collaborators',
                  onPressed: () => _showCollaboratorsSheet(context),
                ),
                IconButton(
                  icon: const Icon(Icons.analytics_outlined),
                  tooltip: 'Analytics',
                  onPressed: () {
                    final analyticsBloc = context.read<AnalyticsBloc>();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => BlocProvider.value(
                          value: analyticsBloc..add(LoadAnalytics(project.id)),
                          child: AnalyticsPage(project: project),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            body: BlocListener<EditSessionBloc, EditSessionState>(
              listener: (context, state) {
                if (state.status == EditSessionStatus.error &&
                    state.error != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(state.error!),
                      backgroundColor: Theme.of(context).colorScheme.error,
                    ),
                  );
                }
              },
              child: Column(
                children: [
                  BlocBuilder<EditSessionBloc, EditSessionState>(
                    builder: (context, state) {
                      if (state.status == EditSessionStatus.success &&
                          state.isEditing) {
                        return EditStatusBanner(projectId: projectId);
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  Expanded(
                    child: BlocBuilder<MediaBloc, MediaState>(
                      builder: (context, state) {
                        if (state.status == MediaStatus.loading &&
                            state.assets.isEmpty) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        if (state.status == MediaStatus.error) {
                          return Center(
                            child: Text(
                              state.error ?? 'An error occurred',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          );
                        }

                        return SafeArea(
                          child: CustomScrollView(
                            slivers: [
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Project Details',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge,
                                      ),
                                      const SizedBox(height: 8),
                                      BlocBuilder<ProjectsBloc, ProjectsState>(
                                        builder: (context, state) {
                                          print(
                                              'Description section - ProjectsBloc State: ${state.status}');
                                          print(
                                              'Description section - Projects in state: ${state.projects.length}');
                                          print(
                                              'Description section - Looking for project ID: $projectId');
                                          print(
                                              'Description section - Projects IDs in state: ${state.projects.map((p) => p.id).join(', ')}');

                                          final currentProject =
                                              state.projects.firstWhere(
                                            (p) => p.id == projectId,
                                            orElse: () {
                                              print(
                                                  'Description section - Project not found in state, using fallback project');
                                              return project;
                                            },
                                          );
                                          print(
                                              'Description section - Current project description: ${currentProject.description}');
                                          return Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  currentProject.description,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium,
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.edit),
                                                onPressed: () =>
                                                    _showEditProjectDialog(
                                                        context),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SliverToBoxAdapter(child: Divider()),
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Media',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      ),
                                      BlocBuilder<EditSessionBloc,
                                          EditSessionState>(
                                        builder: (context, editState) {
                                          return FilledButton.icon(
                                            onPressed: editState
                                                    .isCurrentUserEditing
                                                ? () =>
                                                    _showUploadDialog(context)
                                                : null,
                                            icon: const Icon(Icons.add),
                                            label: const Text('Import Media'),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SliverPadding(
                                padding: const EdgeInsets.only(
                                    bottom: kToolbarHeight),
                                sliver: MediaGrid(
                                  assets: state.assets,
                                  onRefresh: () async {
                                    // No need to manually refresh with real-time updates
                                    return Future<void>.value();
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            floatingActionButton: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FloatingActionButton(
                  heroTag: 'chat_fab',
                  onPressed: () => _showChatInterface(context),
                  child: const Icon(Icons.chat),
                ),
                const SizedBox(height: 16),
                // Commenting out duplicate Import Media button
                // FloatingActionButton(
                //   heroTag: 'upload_fab',
                //   onPressed: () => _showUploadDialog(context),
                //   child: const Icon(Icons.add),
                // ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
