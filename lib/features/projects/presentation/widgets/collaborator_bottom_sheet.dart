import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/collaborator.dart';
import '../../domain/entities/collaborator_role.dart';

class CollaboratorBottomSheet extends StatelessWidget {
  final String projectId;
  final List<Collaborator> collaborators;
  final CollaboratorRole currentUserRole;
  final Function(String email) onInvite;
  final Function(String collaboratorId, CollaboratorRole newRole) onRoleChange;
  final Function(String collaboratorId) onRemove;

  const CollaboratorBottomSheet({
    super.key,
    required this.projectId,
    required this.collaborators,
    required this.currentUserRole,
    required this.onInvite,
    required this.onRoleChange,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canManageCollaborators = currentUserRole == CollaboratorRole.owner;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              _buildHandle(theme),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text(
                      'Project Collaborators',
                      style: theme.textTheme.titleLarge,
                    ),
                    const Spacer(),
                    if (canManageCollaborators)
                      FilledButton.icon(
                        onPressed: () => _showInviteDialog(context),
                        icon: const Icon(Icons.person_add),
                        label: const Text('Invite'),
                      ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: collaborators.length,
                  itemBuilder: (context, index) {
                    final collaborator = collaborators[index];
                    return _CollaboratorTile(
                      collaborator: collaborator,
                      canEdit: canManageCollaborators &&
                          collaborator.role != CollaboratorRole.owner,
                      onRoleChange: onRoleChange,
                      onRemove: onRemove,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHandle(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(
        width: 32,
        height: 4,
        decoration: BoxDecoration(
          color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Future<void> _showInviteDialog(BuildContext context) async {
    final emailController = TextEditingController();

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invite Collaborator'),
        content: TextField(
          controller: emailController,
          decoration: const InputDecoration(
            labelText: 'Email Address',
            hintText: 'Enter collaborator\'s email',
          ),
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final email = emailController.text.trim();
              if (email.isNotEmpty) {
                onInvite(email);
                Navigator.pop(context);
              }
            },
            child: const Text('Invite'),
          ),
        ],
      ),
    );
  }
}

class _CollaboratorTile extends StatelessWidget {
  final Collaborator collaborator;
  final bool canEdit;
  final Function(String, CollaboratorRole) onRoleChange;
  final Function(String) onRemove;

  const _CollaboratorTile({
    required this.collaborator,
    required this.canEdit,
    required this.onRoleChange,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      leading: CircleAvatar(
        backgroundImage: collaborator.photoUrl != null
            ? NetworkImage(collaborator.photoUrl!)
            : null,
        child: collaborator.photoUrl == null
            ? Text(
                (collaborator.displayName ?? collaborator.email ?? '')
                    .characters
                    .first
                    .toUpperCase(),
              )
            : null,
      ),
      title: Text(collaborator.displayName ?? collaborator.email ?? 'Unknown'),
      subtitle: Text(collaborator.role.displayName),
      trailing: canEdit
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<CollaboratorRole>(
                  value: collaborator.role,
                  onChanged: (newRole) {
                    if (newRole != null) {
                      onRoleChange(collaborator.id, newRole);
                    }
                  },
                  items: CollaboratorRole.values
                      .where((role) => role != CollaboratorRole.owner)
                      .map((role) => DropdownMenuItem(
                            value: role,
                            child: Text(role.displayName),
                          ))
                      .toList(),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  color: theme.colorScheme.error,
                  onPressed: () => _showRemoveDialog(context),
                ),
              ],
            )
          : null,
    );
  }

  Future<void> _showRemoveDialog(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Collaborator'),
        content: Text(
            'Are you sure you want to remove ${collaborator.displayName ?? collaborator.email} from this project?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              onRemove(collaborator.id);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/collaborator.dart';
import '../../domain/entities/collaborator_role.dart';

class CollaboratorBottomSheet extends StatelessWidget {
  final String projectId;
  final List<Collaborator> collaborators;
  final CollaboratorRole currentUserRole;
  final Function(String email) onInvite;
  final Function(String collaboratorId, CollaboratorRole newRole) onRoleChange;
  final Function(String collaboratorId) onRemove;

  const CollaboratorBottomSheet({
    super.key,
    required this.projectId,
    required this.collaborators,
    required this.currentUserRole,
    required this.onInvite,
    required this.onRoleChange,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canManageCollaborators = currentUserRole == CollaboratorRole.owner;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              _buildHandle(theme),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text(
                      'Project Collaborators',
                      style: theme.textTheme.titleLarge,
                    ),
                    const Spacer(),
                    if (canManageCollaborators)
                      FilledButton.icon(
                        onPressed: () => _showInviteDialog(context),
                        icon: const Icon(Icons.person_add),
                        label: const Text('Invite'),
                      ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: collaborators.length,
                  itemBuilder: (context, index) {
                    final collaborator = collaborators[index];
                    return _CollaboratorTile(
                      collaborator: collaborator,
                      canEdit: canManageCollaborators &&
                          collaborator.role != CollaboratorRole.owner,
                      onRoleChange: onRoleChange,
                      onRemove: onRemove,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHandle(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(
        width: 32,
        height: 4,
        decoration: BoxDecoration(
          color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Future<void> _showInviteDialog(BuildContext context) async {
    final emailController = TextEditingController();

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invite Collaborator'),
        content: TextField(
          controller: emailController,
          decoration: const InputDecoration(
            labelText: 'Email Address',
            hintText: 'Enter collaborator\'s email',
          ),
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final email = emailController.text.trim();
              if (email.isNotEmpty) {
                onInvite(email);
                Navigator.pop(context);
              }
            },
            child: const Text('Invite'),
          ),
        ],
      ),
    );
  }
}

class _CollaboratorTile extends StatelessWidget {
  final Collaborator collaborator;
  final bool canEdit;
  final Function(String, CollaboratorRole) onRoleChange;
  final Function(String) onRemove;

  const _CollaboratorTile({
    required this.collaborator,
    required this.canEdit,
    required this.onRoleChange,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      leading: CircleAvatar(
        backgroundImage: collaborator.photoUrl != null
            ? NetworkImage(collaborator.photoUrl!)
            : null,
        child: collaborator.photoUrl == null
            ? Text(
                (collaborator.displayName ?? collaborator.email ?? '')
                    .characters
                    .first
                    .toUpperCase(),
              )
            : null,
      ),
      title: Text(collaborator.displayName ?? collaborator.email ?? 'Unknown'),
      subtitle: Text(collaborator.role.displayName),
      trailing: canEdit
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<CollaboratorRole>(
                  value: collaborator.role,
                  onChanged: (newRole) {
                    if (newRole != null) {
                      onRoleChange(collaborator.id, newRole);
                    }
                  },
                  items: CollaboratorRole.values
                      .where((role) => role != CollaboratorRole.owner)
                      .map((role) => DropdownMenuItem(
                            value: role,
                            child: Text(role.displayName),
                          ))
                      .toList(),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  color: theme.colorScheme.error,
                  onPressed: () => _showRemoveDialog(context),
                ),
              ],
            )
          : null,
    );
  }

  Future<void> _showRemoveDialog(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Collaborator'),
        content: Text(
            'Are you sure you want to remove ${collaborator.displayName ?? collaborator.email} from this project?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              onRemove(collaborator.id);
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
