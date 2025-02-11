import 'package:equatable/equatable.dart';

class EditSession extends Equatable {
  final String id;
  final String projectId;
  final String userId;
  final String userDisplayName;
  final DateTime startedAt;
  final DateTime lastActivityAt;
  final bool isActive;

  const EditSession({
    required this.id,
    required this.projectId,
    required this.userId,
    required this.userDisplayName,
    required this.startedAt,
    required this.lastActivityAt,
    this.isActive = true,
  });

  EditSession copyWith({
    String? id,
    String? projectId,
    String? userId,
    String? userDisplayName,
    DateTime? startedAt,
    DateTime? lastActivityAt,
    bool? isActive,
  }) {
    return EditSession(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      userId: userId ?? this.userId,
      userDisplayName: userDisplayName ?? this.userDisplayName,
      startedAt: startedAt ?? this.startedAt,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  List<Object?> get props => [
        id,
        projectId,
        userId,
        userDisplayName,
        startedAt,
        lastActivityAt,
        isActive,
      ];
}
