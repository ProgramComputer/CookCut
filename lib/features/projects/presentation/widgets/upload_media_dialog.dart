import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/presentation/utils/snackbar_utils.dart';
import '../../domain/entities/media_asset.dart';
import '../bloc/media_bloc.dart';

class UploadMediaDialog extends StatefulWidget {
  final String projectId;

  const UploadMediaDialog({
    super.key,
    required this.projectId,
  });

  @override
  State<UploadMediaDialog> createState() => _UploadMediaDialogState();
}

class _UploadMediaDialogState extends State<UploadMediaDialog> {
  MediaType _selectedType = MediaType.rawFootage;
  String? _selectedFilePath;
  String? _selectedFileName;
  bool _isUploading = false;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: _selectedType == MediaType.audio ? FileType.audio : FileType.video,
      allowMultiple: false,
    );

    if (result != null) {
      setState(() {
        _selectedFilePath = result.files.single.path;
        _selectedFileName = result.files.single.name;
      });
    }
  }

  Future<void> _handleUpload() async {
    if (_selectedFilePath == null) {
      showErrorSnackBar(context, 'Please select a file first');
      return;
    }

    setState(() => _isUploading = true);

    try {
      context.read<MediaBloc>().add(
            UploadMedia(
              projectId: widget.projectId,
              filePath: _selectedFilePath!,
              type: _selectedType,
            ),
          );

      if (!mounted) return;
      context.pop();
      showSuccessSnackBar(context, 'Media uploaded successfully');
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Failed to upload media: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Upload Media'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<MediaType>(
            value: _selectedType,
            decoration: const InputDecoration(
              labelText: 'Media Type',
              hintText: 'Select media type',
            ),
            items: MediaType.values
                .where((type) =>
                    type != MediaType.thumbnail) // Hide thumbnail type
                .map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(type.name),
              );
            }).toList(),
            onChanged: _isUploading
                ? null
                : (value) {
                    if (value != null) {
                      setState(() {
                        _selectedType = value;
                        // Clear selected file if type changes
                        _selectedFilePath = null;
                        _selectedFileName = null;
                      });
                    }
                  },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  _selectedFileName ?? 'No file selected',
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: _isUploading ? null : _pickFile,
                icon: const Icon(Icons.attach_file),
                label: const Text('Choose File'),
              ),
            ],
          ),
          if (_isUploading) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            Text(
              'Uploading media...',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isUploading
              ? null
              : () {
                  context.pop();
                },
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isUploading ? null : _handleUpload,
          child: const Text('Upload'),
        ),
      ],
    );
  }
}
