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
      ],
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(
              project.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onBackground,
                  ),
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
                EditStatusBanner(projectId: projectId),
                Expanded(
                  child: BlocBuilder<MediaBloc, MediaState>(
                    builder: (context, state) {
                      if (state.status == MediaStatus.loading &&
                          state.assets.isEmpty) {
                        return const Center(child: CircularProgressIndicator());
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Project Details',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      project.description,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
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
                                              ? () => _showUploadDialog(context)
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
                              padding:
                                  const EdgeInsets.only(bottom: kToolbarHeight),
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
        ),
      ),
    );
  }
}
