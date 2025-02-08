import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../features/projects/presentation/pages/video_import_page.dart';
import '../../features/projects/presentation/pages/projects_list_page.dart';
import '../../features/projects/presentation/pages/project_detail_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth_state.dart';
import '../../features/projects/domain/entities/project.dart';

final router = GoRouter(
  initialLocation: '/',
  debugLogDiagnostics: true, // Enable debug logging
  redirect: (BuildContext context, GoRouterState state) async {
    final authState = context.read<AuthBloc>().state;
    final isAuthenticated = authState.status == AuthStatus.authenticated;
    final isLoginRoute = state.matchedLocation == '/login';

    // Prevent redirect loops
    if (!isAuthenticated && !isLoginRoute) {
      return '/login';
    }
    if (isAuthenticated && isLoginRoute) {
      return '/';
    }
    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const LoginPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    ),
    GoRoute(
      path: '/',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const ProjectsListPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    ),
    GoRoute(
      path: '/projects/:projectId',
      pageBuilder: (context, state) {
        final projectId = state.pathParameters['projectId']!;
        final project = state.extra as Project;
        return CustomTransitionPage(
          key: state.pageKey,
          child: ProjectDetailPage(
            projectId: projectId,
            project: project,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        );
      },
    ),
    GoRoute(
      path: '/projects/:projectId/import',
      pageBuilder: (context, state) {
        final projectId = state.pathParameters['projectId']!;
        return CustomTransitionPage(
          key: state.pageKey,
          child: VideoImportPage(projectId: projectId),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        );
      },
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Text('Page not found: ${state.uri}'),
    ),
  ),
);
