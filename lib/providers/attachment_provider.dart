import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:summerschool/models/attachment_model.dart';
import 'package:summerschool/services/attachment_service.dart';
import 'package:url_launcher/url_launcher.dart';

class AttachmentProvider extends ChangeNotifier {
  final AttachmentService _service;

  AttachmentProvider(this._service);

  List<AttachmentModel> _attachments = [];
  bool _isLoading = false;
  String? _error;
  bool _isDownloading = false;
  int _downloadProgress = 0;
  String _selectedTargetRole = 'all_servants';
  StreamSubscription<List<AttachmentModel>>? _attachmentsSubscription;

  // Getters
  List<AttachmentModel> get attachments => _attachments;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isDownloading => _isDownloading;
  int get downloadProgress => _downloadProgress;
  String get selectedTargetRole => _selectedTargetRole;

  /// Set the target role for uploads
  void setTargetRole(String targetRole) {
    debugPrint('[ATTACHMENT PROVIDER] selected targetRole=$targetRole');
    _selectedTargetRole = targetRole;
    notifyListeners();
  }

  /// Start listening to attachments for a specific user role (realtime)
  void startListeningForRole(String userRole, String stage) {
    debugPrint(
      '[ATTACHMENT PROVIDER] Starting to listen for userRole=$userRole',
    );
    _attachmentsSubscription?.cancel();
    _isLoading = true;
    _error = null;
    notifyListeners();

    _attachmentsSubscription = _service
        .watchAttachmentsForRole(userRole, stage)
        .listen(
          (attachments) {
            debugPrint(
              '[ATTACHMENT PROVIDER] Received ${attachments.length} attachments for role=$userRole',
            );
            _attachments = attachments;
            _isLoading = false;
            _error = null;
            notifyListeners();
          },
          onError: (error) {
            debugPrint('[ATTACHMENT PROVIDER] Stream error: $error');
            _isLoading = false;
            _error = error.toString();
            notifyListeners();
          },
        );
  }

  /// Start listening to attachments for a specific stage (realtime updates)
  /// DEPRECATED: Use startListeningForRole instead
  void startListening(String stage) {
    debugPrint('[ATTACHMENT PROVIDER] Starting to listen for stage=$stage');
    _attachmentsSubscription?.cancel();
    _isLoading = true;
    _error = null;
    notifyListeners();

    _attachmentsSubscription = _service
        .watchAttachmentsForStage(stage)
        .listen(
          (attachments) {
            debugPrint(
              '[ATTACHMENT PROVIDER] Received ${attachments.length} attachments',
            );
            _attachments = attachments;
            _isLoading = false;
            _error = null;
            notifyListeners();
          },
          onError: (error) {
            debugPrint('[ATTACHMENT PROVIDER] Stream error: $error');
            _isLoading = false;
            _error = error.toString();
            notifyListeners();
          },
        );
  }

  /// Open attachment URL in external browser/app (Cloudinary hosted)
  Future<void> openAttachment(AttachmentModel attachment) async {
    try {
      final url = attachment.fileUrl;
      debugPrint('[ATTACHMENT PROVIDER] Launching URL: $url');
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch $url');
      }
      debugPrint('[ATTACHMENT PROVIDER] Launch successful');
    } catch (e) {
      debugPrint('[ATTACHMENT PROVIDER] Launch failed: $e');
      rethrow;
    }
  }

  /// Upload attachment file to Firebase Storage and Firestore
  Future<void> uploadAttachmentFromBytes({
    required Uint8List bytes,
    required String fileName,
    required int fileSize,
    required String title,
    required String stage,
    required String uploadedBy,
    dynamic senderUserModel,
    dynamic notificationService,
  }) async {
    try {
      debugPrint(
        '[ATTACHMENT PROVIDER] Starting upload for fileName=$fileName, targetRole=$_selectedTargetRole',
      );

      await _service.uploadAttachmentFromBytes(
        bytes: bytes,
        fileName: fileName,
        fileSize: fileSize,
        title: title,
        stage: stage,
        uploadedBy: uploadedBy,
        targetRole: _selectedTargetRole,
        senderUserModel: senderUserModel,
        notificationService: notificationService,
      );

      debugPrint('[ATTACHMENT PROVIDER] Upload completed');
    } catch (e) {
      debugPrint('[ATTACHMENT PROVIDER] Upload failed: $e');
      _error = 'Upload failed: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Upload attachment file to Firebase Storage and Firestore
  Future<void> uploadAttachmentWithProgress({
    required File file,
    required String fileName,
    required String title,
    required String stage,
    required String uploadedBy,
    dynamic senderUserModel,
    dynamic notificationService,
  }) async {
    try {
      debugPrint(
        '[ATTACHMENT PROVIDER] Starting upload for fileName=$fileName, targetRole=$_selectedTargetRole',
      );

      await _service.uploadAttachment(
        file: file,
        fileName: fileName,
        title: title,
        stage: stage,
        uploadedBy: uploadedBy,
        targetRole: _selectedTargetRole,
        senderUserModel: senderUserModel,
        notificationService: notificationService,
      );

      debugPrint('[ATTACHMENT PROVIDER] Upload completed');
    } catch (e) {
      debugPrint('[ATTACHMENT PROVIDER] Upload failed: $e');
      _error = 'Upload failed: $e';
      notifyListeners();
      rethrow;
    }
  }

  /// Delete attachment
  Future<void> deleteAttachment(AttachmentModel attachment) async {
    try {
      debugPrint('[ATTACHMENT PROVIDER] Deleting attachment ${attachment.id}');
      await _service.deleteAttachment(attachment);
      debugPrint('[ATTACHMENT PROVIDER] Attachment deleted');
    } catch (e) {
      debugPrint('[ATTACHMENT PROVIDER] Delete failed: $e');
      _error = 'Failed to delete: $e';
      notifyListeners();
      rethrow;
    }
  }

  @override
  void dispose() {
    _attachmentsSubscription?.cancel();
    super.dispose();
  }
}
