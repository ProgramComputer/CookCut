import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/presentation/utils/snackbar_utils.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_event.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../domain/entities/project.dart';
import '../bloc/projects_bloc.dart';
import '../widgets/project_card.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../data/repositories/project_repository_impl.dart';
import '../widgets/create_project_dialog.dart';
import 'package:go_router/go_router.dart';

class ProjectsListPage extends StatelessWidget {
  const ProjectsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ProjectsBloc(
        projectRepository: ProjectRepositoryImpl(),
      )..add(const LoadProjects()),
      child: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state.status == AuthStatus.unauthenticated) {
            context.go('/login');
          }
        },
        child: _ProjectsListView(),
      ),
    );
  }
}

class _ProjectsListView extends StatefulWidget {
  @override
  State<_ProjectsListView> createState() => _ProjectsListViewState();
}

class _ProjectsListViewState extends State<_ProjectsListView> {
  bool _isGridView = true;
  String _searchQuery = '';

  Future<void> _handleSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.logout),
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => context.pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;

      // Show loading indicator
      showLoadingSnackBar(context, 'Signing out...');

      try {
        context.read<AuthBloc>().add(const SignOutRequested());
      } catch (e) {
        if (!mounted) return;
        showErrorSnackBar(context, 'Failed to sign out: ${e.toString()}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Projects'),
        actions: [
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
            tooltip:
                _isGridView ? 'Switch to list view' : 'Switch to grid view',
            onPressed: () {
              setState(() {
                _isGridView = !_isGridView;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => _handleSignOut(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SearchBar(
              hintText: 'Search projects...',
              leading: const Icon(Icons.search),
              trailing: [
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  ),
              ],
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          Expanded(
            child: BlocBuilder<ProjectsBloc, ProjectsState>(
              builder: (context, state) {
                if (state.status == ProjectsStatus.loading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state.status == ProjectsStatus.error) {
                  return Center(
                    child: Text(
                      state.error ?? 'An error occurred',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  );
                }

                final filteredProjects = state.projects.where((project) {
                  final search = _searchQuery.toLowerCase();
                  return project.title.toLowerCase().contains(search) ||
                      project.description.toLowerCase().contains(search);
                }).toList();

                if (filteredProjects.isEmpty && _searchQuery.isNotEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No matching projects found',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try different search terms',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  );
                }

                if (state.projects.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.movie_creation_outlined,
                          size: 64,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No projects yet',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create your first cooking video project',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: () => _showCreateProjectDialog(context),
                          icon: const Icon(Icons.add),
                          label: const Text('Create Project'),
                        ),
                      ],
                    ),
                  );
                }

                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: _buildAnalyticsSummary(context, filteredProjects),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.all(16.0),
                      sliver: _isGridView
                          ? _buildGridView(context, filteredProjects)
                          : _buildListView(context, filteredProjects),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: BlocBuilder<ProjectsBloc, ProjectsState>(
        builder: (context, state) {
          if (state.projects.isEmpty) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: () => _showCreateProjectDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('New Project'),
          );
        },
      ),
    );
  }

  Widget _buildGridView(BuildContext context, List<Project> projects) {
    return SliverGrid(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final project = projects[index];
          return ProjectCard(
            project: project,
            onTap: () {
              // TODO: Navigate to project details
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Project details coming soon')),
              );
            },
          );
        },
        childCount: projects.length,
      ),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 400,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.2,
      ),
    );
  }

  Widget _buildListView(BuildContext context, List<Project> projects) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final project = projects[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () {
                  // TODO: Navigate to project details
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Project details coming soon')),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      if (project.thumbnailUrl != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 120,
                            height: 68,
                            child: Image.network(
                              project.thumbnailUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                  child: Icon(
                                    Icons.movie,
                                    size: 32,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              project.title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              project.description,
                              style: Theme.of(context).textTheme.bodyMedium,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.visibility_outlined,
                                  size: 16,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${project.analytics.views}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(width: 16),
                                Icon(
                                  Icons.people_outline,
                                  size: 16,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${project.collaboratorsCount}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const Spacer(),
                                Text(
                                  timeago.format(project.updatedAt),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
        childCount: projects.length,
      ),
    );
  }

  Widget _buildAnalyticsSummary(BuildContext context, List<Project> projects) {
    final totalViews = projects.fold<int>(
      0,
      (sum, project) => sum + project.analytics.views,
    );
    final avgEngagement = projects.isEmpty
        ? 0.0
        : projects.fold<double>(
              0.0,
              (sum, project) => sum + project.analytics.engagementRate,
            ) /
            projects.length;

    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Analytics Overview',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _AnalyticsTile(
                    icon: Icons.visibility_outlined,
                    label: 'Total Views',
                    value: totalViews.toString(),
                  ),
                ),
                Expanded(
                  child: _AnalyticsTile(
                    icon: Icons.trending_up_outlined,
                    label: 'Avg. Engagement',
                    value: '${(avgEngagement * 100).toStringAsFixed(1)}%',
                  ),
                ),
                Expanded(
                  child: _AnalyticsTile(
                    icon: Icons.video_library_outlined,
                    label: 'Projects',
                    value: projects.length.toString(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateProjectDialog(BuildContext context) {
    final projectsBloc = context.read<ProjectsBloc>();
    showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: projectsBloc,
        child: const CreateProjectDialog(),
      ),
    );
  }
}

class _AnalyticsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _AnalyticsTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          size: 24,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
