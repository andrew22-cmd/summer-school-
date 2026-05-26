import 'package:cloud_firestore/cloud_firestore.dart';

class AttachmentModel {
  final String id;
  final String title;
  final String fileName;
  final String fileUrl;
  final int fileSize; // in bytes
  final String uploadedBy;
  final String targetStage; // e.g., "3 M"
  final String stage_norm; // e.g., "3m"
  final String targetRole; // "managers", "member_managers", "all_servants"
  final DateTime createdAt;

  AttachmentModel({
    required this.id,
    required this.title,
    required this.fileName,
    required this.fileUrl,
    required this.fileSize,
    required this.uploadedBy,
    required this.targetStage,
    required this.stage_norm,
    required this.targetRole,
    required this.createdAt,
  });

  /// Convert Firestore document to AttachmentModel
  factory AttachmentModel.fromMap(Map<String, dynamic> map, String docId) {
    return AttachmentModel(
      id: docId,
      title: map['title'] ?? '',
      fileName: map['fileName'] ?? '',
      fileUrl: map['fileUrl'] ?? '',
      fileSize: map['fileSize'] ?? 0,
      uploadedBy: map['uploadedBy'] ?? '',
      targetStage: map['targetStage'] ?? '',
      stage_norm: map['stage_norm'] ?? '',
      targetRole: map['targetRole'] ?? 'all_servants',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Convert AttachmentModel to Firestore-compatible map
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'fileName': fileName,
      'fileUrl': fileUrl,
      'fileSize': fileSize,
      'uploadedBy': uploadedBy,
      'targetStage': targetStage,
      'stage_norm': stage_norm,
      'targetRole': targetRole,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Format file size for display (e.g., "3.2 MB")
  String get fileSizeFormatted {
    if (fileSize < 1024) {
      return '${fileSize} B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(2)} KB';
    } else {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
  }

  /// Get file extension from fileName
  String get fileExtension {
    if (fileName.contains('.')) {
      return fileName.split('.').last.toUpperCase();
    }
    return 'FILE';
  }

  /// Check if file is PDF
  bool get isPdf => fileName.toLowerCase().endsWith('.pdf');

  /// Check if file is image
  bool get isImage {
    final name = fileName.toLowerCase();
    return name.endsWith('.png') ||
        name.endsWith('.jpg') ||
        name.endsWith('.jpeg');
  }

  /// Check if file is document
  bool get isDocument {
    final name = fileName.toLowerCase();
    return name.endsWith('.docx') || name.endsWith('.doc');
  }
}
