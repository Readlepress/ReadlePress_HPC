import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Camera/gallery picker that stores photos locally and queues for upload.
class EvidenceAttachment extends StatefulWidget {
  const EvidenceAttachment({
    super.key,
    required this.onFilesChanged,
    this.initialFiles = const [],
    this.maxFiles = 5,
  });

  final ValueChanged<List<File>> onFilesChanged;
  final List<File> initialFiles;
  final int maxFiles;

  @override
  State<EvidenceAttachment> createState() => _EvidenceAttachmentState();
}

class _EvidenceAttachmentState extends State<EvidenceAttachment> {
  late List<File> _files;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _files = List.from(widget.initialFiles);
  }

  Future<void> _pickFromCamera() async {
    if (_files.length >= widget.maxFiles) {
      _showMaxFilesMessage();
      return;
    }
    try {
      final image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
      );
      if (image != null) {
        setState(() => _files.add(File(image.path)));
        widget.onFilesChanged(_files);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera not available: $e')),
        );
      }
    }
  }

  Future<void> _pickFromGallery() async {
    if (_files.length >= widget.maxFiles) {
      _showMaxFilesMessage();
      return;
    }
    try {
      final images = await _picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1920,
      );
      final remaining = widget.maxFiles - _files.length;
      final toAdd = images.take(remaining).map((f) => File(f.path)).toList();
      if (toAdd.isNotEmpty) {
        setState(() => _files.addAll(toAdd));
        widget.onFilesChanged(_files);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gallery not available: $e')),
        );
      }
    }
  }

  void _removeFile(int index) {
    setState(() => _files.removeAt(index));
    widget.onFilesChanged(_files);
  }

  void _showMaxFilesMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Maximum ${widget.maxFiles} files allowed'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Evidence (${_files.length}/${widget.maxFiles})',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        if (_files.isNotEmpty) ...[
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _files.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) => _buildThumbnail(ctx, i),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed:
                    _files.length < widget.maxFiles ? _pickFromCamera : null,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Camera'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed:
                    _files.length < widget.maxFiles ? _pickFromGallery : null,
                icon: const Icon(Icons.photo_library),
                label: const Text('Gallery'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildThumbnail(BuildContext context, int index) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            _files[index],
            width: 100,
            height: 100,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 100,
              height: 100,
              color: Colors.grey.shade200,
              child: const Icon(Icons.broken_image),
            ),
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: Material(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _removeFile(index),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
