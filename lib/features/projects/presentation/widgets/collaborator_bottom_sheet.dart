import 'package:flutter/material.dart';
import '../../domain/entities/collaborator.dart';
import '../../domain/entities/collaborator_role.dart';

class CollaboratorBottomSheet extends StatefulWidget {
  final String projectId;
  final List<Collaborator> collaborators;
  final CollaboratorRole currentUserRole;
  final Function(String) onInvite;
  final Function(String, CollaboratorRole) onRoleChange;
  final Function(String) onRemove;

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
  State<CollaboratorBottomSheet> createState() =>
      _CollaboratorBottomSheetState();
}

class _CollaboratorBottomSheetState extends State<CollaboratorBottomSheet> {
  final _emailController = TextEditingController();
  bool _isInviting = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canManageCollaborators =
        widget.currentUserRole == CollaboratorRole.owner;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Project Collaborators',
                  style: theme.textTheme.titleLarge,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Invite Section (Moved to top for better visibility)
          if (canManageCollaborators) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!_isInviting)
                    FilledButton.icon(
                      onPressed: () => setState(() => _isInviting = true),
                      icon: const Icon(Icons.person_add),
                      label: const Text('Invite Collaborator'),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _emailController,
                            decoration: const InputDecoration(
                              hintText: 'Enter email address',
                              prefixIcon: Icon(Icons.email),
                              errorMaxLines: 2,
                            ),
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (email) {
                              if (email.isNotEmpty) {
                                widget.onInvite(email.trim());
                                _emailController.clear();
                                setState(() => _isInviting = false);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          onPressed: () {
                            final email = _emailController.text.trim();
                            if (email.isNotEmpty) {
                              widget.onInvite(email);
                              _emailController.clear();
                              setState(() => _isInviting = false);
                            }
                          },
                          icon: const Icon(Icons.send),
                        ),
                        const SizedBox(width: 8),
                        IconButton.outlined(
                          onPressed: () => setState(() => _isInviting = false),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
          ],

          // Collaborator List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: widget.collaborators.length,
              itemBuilder: (context, index) {
                final collaborator = widget.collaborators[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      (collaborator.displayName?.isNotEmpty == true
                              ? collaborator.displayName!
                              : collaborator.email ?? 'Unknown')[0]
                          .toUpperCase(),
                      style: TextStyle(
                          color: theme.colorScheme.onPrimaryContainer),
                    ),
                  ),
                  title: Text(
                    collaborator.displayName ??
                        collaborator.email ??
                        'Unknown User',
                  ),
                  subtitle: Text(
                    collaborator.email ?? 'No email provided',
                  ),
                  trailing: canManageCollaborators
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            DropdownButton<CollaboratorRole>(
                              value: collaborator.role,
                              onChanged:
                                  collaborator.role == CollaboratorRole.owner
                                      ? null
                                      : (newRole) {
                                          if (newRole != null) {
                                            widget.onRoleChange(
                                                collaborator.id, newRole);
                                          }
                                        },
                              items: CollaboratorRole.values
                                  .map((role) => DropdownMenuItem(
                                        value: role,
                                        enabled: role != CollaboratorRole.owner,
                                        child: Text(role.name),
                                      ))
                                  .toList(),
                            ),
                            if (collaborator.role != CollaboratorRole.owner)
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                color: theme.colorScheme.error,
                                onPressed: () =>
                                    widget.onRemove(collaborator.id),
                              ),
                          ],
                        )
                      : Text(collaborator.role.name),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
