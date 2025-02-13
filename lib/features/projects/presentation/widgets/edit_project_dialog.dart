import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/presentation/utils/snackbar_utils.dart';
import '../bloc/projects_bloc.dart';
import '../../domain/entities/project.dart';
import 'loading_overlay.dart';

class EditProjectDialog extends StatefulWidget {
  final Project project;

  const EditProjectDialog({
    super.key,
    required this.project,
  });

  @override
  State<EditProjectDialog> createState() => _EditProjectDialogState();
}

class _EditProjectDialogState extends State<EditProjectDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.project.title);
    _descriptionController =
        TextEditingController(text: widget.project.description);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isSubmitting = true);

      try {
        final hasChanges = _titleController.text != widget.project.title ||
            _descriptionController.text != widget.project.description;

        if (!hasChanges) {
          if (!mounted) return;
          context.pop();
          return;
        }

        BlocProvider.of<ProjectsBloc>(context).add(
          UpdateProject(
            projectId: widget.project.id,
            title: _titleController.text != widget.project.title
                ? _titleController.text
                : null,
            description:
                _descriptionController.text != widget.project.description
                    ? _descriptionController.text
                    : null,
          ),
        );

        if (!mounted) return;
        context.pop();
        showSuccessSnackBar(context, 'Project updated successfully');
      } catch (e) {
        if (!mounted) return;
        showErrorSnackBar(context, 'Failed to update project: ${e.toString()}');
      } finally {
        if (mounted) {
          setState(() => _isSubmitting = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isSubmitting,
      message: 'Updating project...',
      child: AlertDialog(
        title: const Text('Edit Project'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'Enter project title',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Enter project description',
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : () => context.pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _isSubmitting ? null : _handleSubmit,
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
