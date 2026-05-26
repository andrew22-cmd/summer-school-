import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:summerschool/core/constants/app_colors.dart';
import 'package:summerschool/models/attachment_model.dart';
import 'package:summerschool/providers/attachment_provider.dart';
import 'package:summerschool/providers/auth_provider.dart';

class AttachmentsScreen extends StatefulWidget {
  const AttachmentsScreen({super.key});

  @override
  State<AttachmentsScreen> createState() => _AttachmentsScreenState();
}

class _AttachmentsScreenState extends State<AttachmentsScreen> {
  String? _startedStage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final stage = user?.stage ?? '';

    if (auth.isLoading || user == null || stage.trim().isEmpty) {
      return;
    }

    if (_startedStage == stage) return;
    _startedStage = stage;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      debugPrint('[ATTACHMENTS SCREEN] Starting for stage="$stage"');
      final provider = context.read<AttachmentProvider>();
      provider.startListening(stage);
    });
  }

  Future<void> _refreshAttachments() async {
    final auth = context.read<AuthProvider>();
    final provider = context.read<AttachmentProvider>();
    provider.startListening(auth.user?.stage ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final attachmentProvider = context.watch<AttachmentProvider>();
    final user = auth.user;

    if (auth.isLoading || user == null || user.stage.trim().isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppColors.surfaceSoft,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        title: const Text('Attachments'),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAttachments,
        child: attachmentProvider.isLoading
            ? const Center(child: CircularProgressIndicator())
            : attachmentProvider.error != null
            ? _buildErrorState(attachmentProvider.error!)
            : attachmentProvider.attachments.isEmpty
            ? _buildEmptyState()
            : _buildAttachmentsList(attachmentProvider),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open_rounded, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No attachments yet',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Error: $error',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.red[700]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentsList(AttachmentProvider provider) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: provider.attachments.length,
      itemBuilder: (context, index) {
        final attachment = provider.attachments[index];
        return _AttachmentCard(attachment: attachment);
      },
    );
  }
}

class _AttachmentCard extends StatefulWidget {
  final AttachmentModel attachment;

  const _AttachmentCard({required this.attachment});

  @override
  State<_AttachmentCard> createState() => _AttachmentCardState();
}

class _AttachmentCardState extends State<_AttachmentCard> {
  bool _isDownloading = false;
  int _progress = 0;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // File icon and title row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFileIcon(widget.attachment),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.attachment.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.attachment.fileName,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Date and size row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  DateFormat('dd MMM yyyy').format(widget.attachment.createdAt),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
                ),
                Text(
                  widget.attachment.fileSizeFormatted,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Download button or progress
            if (_isDownloading)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _progress / 100,
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$_progress%',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _downloadFile,
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('DOWNLOAD'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileIcon(AttachmentModel attachment) {
    IconData icon = Icons.insert_drive_file_rounded;
    Color color = Colors.grey;

    if (attachment.isPdf) {
      icon = Icons.picture_as_pdf_rounded;
      color = Colors.red;
    } else if (attachment.isDocument) {
      icon = Icons.description_rounded;
      color = Colors.blue;
    } else if (attachment.isImage) {
      icon = Icons.image_rounded;
      color = Colors.purple;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 28),
    );
  }

  Future<void> _downloadFile() async {
    final attachmentProvider = context.read<AttachmentProvider>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      setState(() => _isDownloading = true);

      debugPrint(
        '[ATTACHMENTS SCREEN] Starting download for ${widget.attachment.fileName}',
      );

      // Open the hosted file URL (Cloudinary) in external browser/app
      await attachmentProvider.openAttachment(widget.attachment);
      debugPrint(
        '[ATTACHMENTS SCREEN] Opened URL: ${widget.attachment.fileUrl}',
      );

      if (!mounted) return;

      setState(() => _isDownloading = false);

      messenger.showSnackBar(
        SnackBar(
          content: Text('Opened ${widget.attachment.fileName} in browser.'),
        ),
      );
    } catch (e) {
      debugPrint('[ATTACHMENTS SCREEN] Download/open error: $e');
      if (!mounted) return;

      setState(() => _isDownloading = false);

      messenger.showSnackBar(
        SnackBar(
          content: Text('Download failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
