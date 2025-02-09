import 'package:equatable/equatable.dart';
import 'collaborator_role.dart';

class Collaborator extends Equatable {
  final String id;
  final String projectId;
  final String userId;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final CollaboratorRole role;
  final DateTime addedAt;

  const Collaborator({
    required this.id,
    required this.projectId,
    required this.userId,
    this.email,
    this.displayName,
    this.photoUrl,
    required this.role,
    required this.addedAt,
  });

  @override
  List<Object?> get props =>
      [id, projectId, userId, email, displayName, photoUrl, role, addedAt];

  Collaborator copyWith({
    String? id,
    String? projectId,
    String? userId,
    String? email,
    String? displayName,
    String? photoUrl,
    CollaboratorRole? role,
    DateTime? addedAt,
  }) {
    return Collaborator(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      addedAt: addedAt ?? this.addedAt,
    );
  }
}

import 'collaborator_role.dart';

class Collaborator extends Equatable {
  final String id;
  final String projectId;
  final String userId;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final CollaboratorRole role;
  final DateTime addedAt;

  const Collaborator({
    required this.id,
    required this.projectId,
    required this.userId,
    this.email,
    this.displayName,
    this.photoUrl,
    required this.role,
    required this.addedAt,
  });

  @override
  List<Object?> get props =>
      [id, projectId, userId, email, displayName, photoUrl, role, addedAt];

  Collaborator copyWith({
    String? id,
    String? projectId,
    String? userId,
    String? email,
    String? displayName,
    String? photoUrl,
    CollaboratorRole? role,
    DateTime? addedAt,
  }) {
    return Collaborator(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      addedAt: addedAt ?? this.addedAt,
    );
  }
}
