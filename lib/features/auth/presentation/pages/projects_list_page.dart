import 'package:flutter/material.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';

class ProjectsListPage extends StatelessWidget {
  const ProjectsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Projects'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              context.read<AuthBloc>().add(const SignOutRequested());
            },
          ),
        ],
      ),
      body: const Center(
        child: Text('Projects List Coming Soon'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Implement project creation
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Create Project - Coming Soon')),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
