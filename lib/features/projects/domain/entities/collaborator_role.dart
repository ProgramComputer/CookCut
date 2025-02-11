enum CollaboratorRole {
  owner,
  editor,
  viewer;

  String get displayName {
    switch (this) {
      case CollaboratorRole.owner:
        return 'Owner';
      case CollaboratorRole.editor:
        return 'Editor';
      case CollaboratorRole.viewer:
        return 'Viewer';
    }
  }

  String get description {
    switch (this) {
      case CollaboratorRole.owner:
        return 'Can edit, share, and manage collaborators';
      case CollaboratorRole.editor:
        return 'Can edit and comment on the project';
      case CollaboratorRole.viewer:
        return 'Can view and comment on the project';
    }
  }
}
