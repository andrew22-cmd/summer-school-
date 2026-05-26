import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:summerschool/core/constants/app_colors.dart';
import 'package:summerschool/constants/user_roles.dart';
import 'package:summerschool/models/attachment_model.dart';
import 'package:summerschool/providers/attachment_provider.dart';
import 'package:summerschool/providers/auth_provider.dart';

class ManageAttachmentsScreen extends StatefulWidget {
  const ManageAttachmentsScreen({super.key});

  @override
  State<ManageAttachmentsScreen> createState() =>
      _ManageAttachmentsScreenState();
}

class _ManageAttachmentsScreenState extends State<ManageAttachmentsScreen> {
  String? _startedStage;
  PlatformFile? _selectedFile;
  Uint8List? _selectedBytes;
  final TextEditingController _titleController = TextEditingController();
  bool _isUploading = false;
  int _uploadProgress = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final stage = user?.stage ?? '';

    if (auth.isLoading || user == null) return;
    if (_startedStage == stage) return;
    _startedStage = stage;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final userRole = user.role.value;
      debugPrint(
        '[MANAGE ATTACHMENTS] startListeningForRole userRole="$userRole"',
      );
      context.read<AttachmentProvider>().startListeningForRole(userRole, stage);
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    final stage = user?.stage ?? '';
    if (stage.trim().isNotEmpty && user != null) {
      context.read<AttachmentProvider>().startListeningForRole(
        user.role.value,
        stage,
      );
    }
  }

  Future<void> _pickFile() async {
    try {
      debugPrint('[MANAGE ATTACHMENTS] file picker opened');
      final result = await FilePicker.platform.pickFiles(
        withData: true,
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx', 'doc', 'png', 'jpg', 'jpeg'],
        allowMultiple: false,
      );

      final file = result?.files.single;
      if (file == null) return;
      final bytes = file.bytes;
      if (bytes == null) {
        throw Exception('File bytes are unavailable on this platform.');
      }

      setState(() {
        _selectedFile = file;
        _selectedBytes = bytes;
      });
      debugPrint('[MANAGE ATTACHMENTS] file selected: ${file.name}');
    } catch (e) {
      debugPrint('[MANAGE ATTACHMENTS] file picker error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error selecting file: $e')));
    }
  }

  Future<void> _uploadFile() async {
    if (_selectedFile == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a file')));
      return;
    }

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a title')));
      return;
    }

    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('User not found')));
      return;
    }

    // Send file for all users (members, members-manager, managers)
    final targetStage = '';

    final provider = context.read<AttachmentProvider>();
    final fileName = _selectedFile!.name;
    final uploadedBy = user.name.trim().isNotEmpty ? user.name.trim() : user.id;
    final bytes = _selectedBytes;
    final fileSize = bytes?.lengthInBytes ?? _selectedFile!.size;

    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to read file bytes')),
      );
      return;
    }

    try {
      debugPrint('[MANAGE ATTACHMENTS] upload start: $fileName');
      setState(() {
        _isUploading = true;
        _uploadProgress = 10;
      });

      await provider.uploadAttachmentFromBytes(
        bytes: bytes,
        fileName: fileName,
        fileSize: fileSize,
        title: title,
        stage: targetStage,
        uploadedBy: uploadedBy,
      );

      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _uploadProgress = 0;
        _selectedFile = null;
        _selectedBytes = null;
        _titleController.clear();
      });

      debugPrint('[MANAGE ATTACHMENTS] upload success: $fileName');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File uploaded successfully')),
      );
    } catch (e) {
      debugPrint('[MANAGE ATTACHMENTS] upload error: $e');
      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _uploadProgress = 0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final provider = context.watch<AttachmentProvider>();
    final user = auth.user;

    if (auth.isLoading || user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppColors.surfaceSoft,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        title: const Text('Manage Attachments'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildUploadSection(),
            const SizedBox(height: 24),
            Text(
              'Previously Uploaded Files',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (provider.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (provider.error != null)
              _buildErrorState(provider.error!)
            else if (provider.attachments.isEmpty)
              _buildEmptyState()
            else
              ...provider.attachments.map(_buildAttachmentItem),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadSection() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Upload Area',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              enabled: !_isUploading,
              decoration: InputDecoration(
                labelText: 'File title',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildSendToDropdown(),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                children: [
                  Icon(
                    _selectedFile == null
                        ? Icons.cloud_upload_rounded
                        : _fileIconForPath(_selectedFile!.name),
                    size: 44,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _selectedFile == null
                        ? 'No file selected'
                        : _selectedFile!.name,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_selectedFile != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      '${(_selectedFile!.size / (1024 * 1024)).toStringAsFixed(2)} MB',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _isUploading ? null : _pickFile,
                    icon: const Icon(Icons.upload_file_rounded),
                    label: const Text('UPLOAD FILE'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_isUploading) ...[
              LinearProgressIndicator(value: _uploadProgress / 100),
              const SizedBox(height: 8),
              Text('$_uploadProgress%'),
            ] else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _uploadFile,
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('SEND'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentItem(AttachmentModel attachment) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withOpacity(0.1),
          child: Icon(
            _fileIconForPath(attachment.fileName),
            color: AppColors.primary,
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              attachment.title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            _buildTargetRoleBadge(attachment.targetRole),
          ],
        ),
        subtitle: Text(
          '${DateFormat('dd MMM yyyy').format(attachment.createdAt)}\n${attachment.fileSizeFormatted}',
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.download_rounded),
              tooltip: 'Open file',
              onPressed: () async {
                try {
                  debugPrint(
                    '[MANAGE ATTACHMENTS] opening: ${attachment.fileName}',
                  );
                  await context.read<AttachmentProvider>().openAttachment(
                    attachment,
                  );
                  debugPrint(
                    '[MANAGE ATTACHMENTS] opened URL: ${attachment.fileUrl}',
                  );
                } catch (e) {
                  debugPrint('[MANAGE ATTACHMENTS] open error: $e');
                  if (!mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Open failed: $e')));
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_rounded, color: Colors.red),
              tooltip: 'Delete file',
              onPressed: () => _showDeleteConfirmation(attachment),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.folder_open_rounded, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'No files uploaded yet',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Text(
          'Error: $error',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.red.shade700),
        ),
      ),
    );
  }

  IconData _fileIconForPath(String fileName) {
    final name = fileName.toLowerCase();
    if (name.endsWith('.pdf')) return Icons.picture_as_pdf_rounded;
    if (name.endsWith('.docx') || name.endsWith('.doc')) {
      return Icons.description_rounded;
    }
    if (name.endsWith('.png') ||
        name.endsWith('.jpg') ||
        name.endsWith('.jpeg')) {
      return Icons.image_rounded;
    }
    return Icons.insert_drive_file_rounded;
  }

  Widget _buildSendToDropdown() {
    return Consumer<AttachmentProvider>(
      builder: (context, provider, _) {
        return DropdownButtonFormField<String>(
          value: provider.selectedTargetRole,
          onChanged: (value) {
            if (value != null) {
              provider.setTargetRole(value);
            }
          },
          decoration: InputDecoration(
            labelText: 'Send To',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: [
            DropdownMenuItem(
              value: 'managers',
              child: const Text('Managers Only'),
            ),
            DropdownMenuItem(
              value: 'member_managers',
              child: const Text('Member Managers Only'),
            ),
            DropdownMenuItem(
              value: 'all_servants',
              child: const Text('All Servants'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTargetRoleBadge(String targetRole) {
    String displayText;
    Color bgColor;

    switch (targetRole) {
      case 'managers':
        displayText = 'Managers Only';
        bgColor = Colors.red.shade100;
        break;
      case 'member_managers':
        displayText = 'Member Managers';
        bgColor = Colors.orange.shade100;
        break;
      case 'all_servants':
      default:
        displayText = 'All Servants';
        bgColor = Colors.green.shade100;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '[ $displayText ]',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }

  Future<void> _showDeleteConfirmation(AttachmentModel attachment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete File?'),
        content: Text(
          'Are you sure you want to delete "${attachment.fileName}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      if (!mounted) return;
      debugPrint('[MANAGE ATTACHMENTS] deleting: ${attachment.fileName}');
      await context.read<AttachmentProvider>().deleteAttachment(attachment);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${attachment.fileName} deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('[MANAGE ATTACHMENTS] delete error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
