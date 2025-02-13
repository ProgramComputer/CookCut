import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/project.dart';
import '../../domain/repositories/project_repository.dart';

class ProjectRepositoryImpl implements ProjectRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  ProjectRepositoryImpl({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  @override
  Future<List<Project>> getProjects() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    // Get projects where user is owner
    final ownedProjects = await _firestore
        .collection('projects')
        .where('user_id', isEqualTo: userId)
        .get();

    // Get projects where user is collaborator
    final collaboratingProjects = await _firestore
        .collection('projects')
        .where('collaborators.$userId', isEqualTo: true)
        .get();

    // Combine and convert to Project entities
    final projects = [
      ...ownedProjects.docs,
      ...collaboratingProjects.docs,
    ].map((doc) {
      final data = doc.data();
      return Project(
        id: doc.id,
        userId: data['user_id'] as String,
        title: data['title'] as String,
        description: data['description'] as String,
        createdAt: (data['created_at'] as Timestamp).toDate(),
        updatedAt: (data['updated_at'] as Timestamp).toDate(),
        thumbnailUrl: data['thumbnail_url'] as String?,
        collaboratorsCount:
            (data['collaborators'] as Map<String, dynamic>?)?.length ?? 0,
        analytics: ProjectAnalytics(
          views:
              (data['analytics'] as Map<String, dynamic>)['views'] as int? ?? 0,
          engagementRate: (data['analytics']
                  as Map<String, dynamic>)['engagement_rate'] as double? ??
              0.0,
          lastUpdated: ((data['analytics']
                      as Map<String, dynamic>)['last_updated'] as Timestamp?)
                  ?.toDate() ??
              DateTime.now(),
        ),
      );
    }).toList();

    // Sort by most recently updated
    projects.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return projects;
  }

  @override
  Future<Project> createProject({
    required String title,
    required String description,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    final now = DateTime.now();
    final projectData = {
      'user_id': userId,
      'title': title,
      'description': description,
      'created_at': Timestamp.fromDate(now),
      'updated_at': Timestamp.fromDate(now),
      'collaborators': <String, bool>{},
      'analytics': {
        'views': 0,
        'engagement_rate': 0.0,
        'last_updated': Timestamp.fromDate(now),
      },
    };

    final docRef = await _firestore.collection('projects').add(projectData);

    return Project(
      id: docRef.id,
      userId: userId,
      title: title,
      description: description,
      createdAt: now,
      updatedAt: now,
      collaboratorsCount: 0,
      analytics: ProjectAnalytics.defaultAnalytics,
    );
  }

  @override
  Future<Project> updateProject({
    required String projectId,
    String? title,
    String? description,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    final projectRef = _firestore.collection('projects').doc(projectId);
    final project = await projectRef.get();

    if (!project.exists) throw Exception('Project not found');
    if (project.data()?['user_id'] != userId) {
      throw Exception('Not authorized to update this project');
    }

    final now = DateTime.now();
    final updates = {
      'updated_at': Timestamp.fromDate(now),
      if (title != null) 'title': title,
      if (description != null) 'description': description,
    };

    await projectRef.update(updates);

    // Get the updated project data
    final updatedProject = await projectRef.get();
    final data = updatedProject.data()!;

    return Project(
      id: updatedProject.id,
      userId: data['user_id'] as String,
      title: data['title'] as String,
      description: data['description'] as String,
      createdAt: (data['created_at'] as Timestamp).toDate(),
      updatedAt: (data['updated_at'] as Timestamp).toDate(),
      thumbnailUrl: data['thumbnail_url'] as String?,
      collaboratorsCount:
          (data['collaborators'] as Map<String, dynamic>?)?.length ?? 0,
      analytics: ProjectAnalytics(
        views:
            (data['analytics'] as Map<String, dynamic>)['views'] as int? ?? 0,
        engagementRate: (data['analytics']
                as Map<String, dynamic>)['engagement_rate'] as double? ??
            0.0,
        lastUpdated: ((data['analytics']
                    as Map<String, dynamic>)['last_updated'] as Timestamp?)
                ?.toDate() ??
            DateTime.now(),
      ),
    );
  }

  @override
  Future<void> deleteProject(String projectId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    final projectRef = _firestore.collection('projects').doc(projectId);
    final project = await projectRef.get();

    if (!project.exists) throw Exception('Project not found');
    if (project.data()?['user_id'] != userId) {
      throw Exception('Not authorized to delete this project');
    }

    // Delete all subcollections first
    await Future.wait([
      _deleteCollection(projectRef.collection('media_assets')),
      _deleteCollection(projectRef.collection('edit_sessions')),
      _deleteCollection(projectRef.collection('collaborators')),
      _deleteCollection(projectRef.collection('analytics')),
    ]);

    // Delete the project document
    await projectRef.delete();
  }

  Future<void> _deleteCollection(CollectionReference collection) async {
    final snapshots = await collection.get();
    for (final doc in snapshots.docs) {
      await doc.reference.delete();
    }
  }
}
