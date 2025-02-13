import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/edit_session_bloc.dart';

class EditStatusBanner extends StatelessWidget {
  final String projectId;

  const EditStatusBanner({
    super.key,
    required this.projectId,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EditSessionBloc, EditSessionState>(
      builder: (context, state) {
        if (state.status == EditSessionStatus.loading) {
          return const LinearProgressIndicator();
        }

        if (state.currentSession == null) {
          if (state.canEdit) {
            // Temporarily removed Start Editing button
            // return FilledButton.icon(
            //   onPressed: () {
            //     context.read<EditSessionBloc>().add(StartEditing(projectId));
            //   },
            //   icon: const Icon(Icons.edit),
            //   label: const Text('Start Editing'),
            // );
            return const SizedBox.shrink();
          }
          return const SizedBox.shrink();
        }

        final isCurrentUser = state.isCurrentUserEditing;
        final theme = Theme.of(context);

        return Material(
          color: isCurrentUser
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Icon(
                  isCurrentUser ? Icons.edit : Icons.lock,
                  color: isCurrentUser
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isCurrentUser
                        ? 'You are currently editing'
                        : '${state.currentSession?.userDisplayName} is currently editing',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: isCurrentUser
                          ? theme.colorScheme.onPrimaryContainer
                          : theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
                if (isCurrentUser)
                  TextButton.icon(
                    onPressed: () {
                      context
                          .read<EditSessionBloc>()
                          .add(StopEditing(state.currentSession!.id));
                    },
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop Editing'),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
