import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:summerschool/models/attachment_model.dart';
import 'package:summerschool/services/notification_service.dart';

class AttachmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Dio _dio = Dio();

  /// Normalize stage (e.g., "3 M" -> "3m")
  static String normalizeStage(String stage) {
    return stage.replaceAll(' ', '').toLowerCase();
  }

  /// Watch attachments filtered by user role (realtime updates)
  /// Managers see: everything
  /// MemberManagers see: member_managers + all_servants
  /// Members see: all_servants only
  Stream<List<AttachmentModel>> watchAttachmentsForRole(
    String userRole,
    String stage,
  ) {
    debugPrint(
      '[ATTACHMENT SERVICE] watching attachments for userRole=$userRole',
    );

    // Determine which targetRoles are visible to this user
    List<String> allowedTargetRoles = [];

    if (userRole == 'manager') {
      // Managers see everything
      allowedTargetRoles = ['managers', 'member_managers', 'all_servants'];
    } else if (userRole == 'member_manager') {
      // Member managers see member_managers and all_servants
      allowedTargetRoles = ['member_managers', 'all_servants'];
    } else {
      // Members see only all_servants
      allowedTargetRoles = ['all_servants'];
    }

    debugPrint(
      '[ATTACHMENT SERVICE] allowed target roles: $allowedTargetRoles',
    );

    // Query files where targetRole is in allowed list
    final query = _firestore
        .collection('attachments')
        .where('targetRole', whereIn: allowedTargetRoles)
        .snapshots();

    return query.map((snapshot) {
      final attachments = snapshot.docs
          .map((doc) => AttachmentModel.fromMap(doc.data(), doc.id))
          .toList();

      // Sort by createdAt descending (newest first)
      attachments.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      debugPrint(
        '[ATTACHMENT SERVICE] attachments snapshot received: ${attachments.length} items for role=$userRole',
      );
      return attachments;
    });
  }

  /// Watch attachments for a specific stage (realtime updates)
  /// Returns files for the user's stage + all files uploaded for everyone (stage_norm empty)
  /// DEPRECATED: Use watchAttachmentsForRole instead
  Stream<List<AttachmentModel>> watchAttachmentsForStage(String stage) {
    final normalized = normalizeStage(stage);
    debugPrint(
      '[ATTACHMENT SERVICE] watching attachments for stage_norm=$normalized',
    );

    // Query files for user's stage OR files for all users (stage_norm empty)
    final query = _firestore
        .collection('attachments')
        .where(
          'stage_norm',
          whereIn: normalized.isEmpty ? [''] : [normalized, ''],
        )
        .snapshots();

    return query.map((snapshot) {
      final attachments = snapshot.docs
          .map((doc) => AttachmentModel.fromMap(doc.data(), doc.id))
          .toList();

      // Sort by createdAt descending (newest first)
      attachments.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      debugPrint(
        '[ATTACHMENT SERVICE] attachments snapshot received: ${attachments.length} items',
      );
      return attachments;
    });
  }

  /// Upload file bytes to Cloudinary and save metadata to Firestore
  /// Pass senderUserModel to trigger automatic notifications
  Future<void> uploadAttachmentFromBytes({
    required Uint8List bytes,
    required String fileName,
    required int fileSize,
    required String title,
    required String stage,
    required String uploadedBy,
    required String targetRole,
    dynamic senderUserModel, // UserModel for notifications
    NotificationService? notificationService,
  }) async {
    try {
      final normalized = normalizeStage(stage);

      debugPrint(
        '[ATTACHMENT SERVICE] Starting upload for fileName=$fileName, size=$fileSize bytes, targetRole=$targetRole',
      );

      // Cloudinary upload
      const cloudinaryUrl =
          'https://api.cloudinary.com/v1_1/djniksauo/raw/upload';
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: fileName),
        'upload_preset': 'summerschool',
      });

      debugPrint('[ATTACHMENT SERVICE] Cloudinary upload started');

      final response = await _dio.post(
        cloudinaryUrl,
        data: formData,
        onSendProgress: (sent, total) {
          final progress = total > 0 ? (sent / total) * 100 : 0;
          debugPrint(
            '[ATTACHMENT SERVICE] UPLOAD PROGRESS: ${progress.toStringAsFixed(2)}%',
          );
        },
      );

      debugPrint(
        '[ATTACHMENT SERVICE] Cloudinary response status: ${response.statusCode}',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        var fileUrl = response.data['secure_url'] as String? ?? '';
        // Add fl_attachment flag for proper content delivery/download
        fileUrl = fileUrl.replaceAll('/upload/', '/upload/fl_attachment/');
        debugPrint(
          '[ATTACHMENT SERVICE] Cloudinary secure_url (with fl_attachment): $fileUrl',
        );

        final docRef = _firestore.collection('attachments').doc();
        final attachmentData = AttachmentModel(
          id: docRef.id,
          title: title,
          fileName: fileName,
          fileUrl: fileUrl,
          fileSize: fileSize,
          uploadedBy: uploadedBy,
          targetStage: stage,
          stage_norm: normalized,
          targetRole: targetRole,
          createdAt: DateTime.now(),
        );

        await docRef.set(attachmentData.toMap());

        debugPrint(
          '[ATTACHMENT SERVICE] Attachment metadata saved to Firestore with id=${docRef.id}, targetRole=$targetRole',
        );

        // Trigger automatic notification
        if (senderUserModel != null && notificationService != null) {
          try {
            // Determine target recipients based on targetRole
            List<String> targetRoles = [];
            List<String> targetStages = [];

            if (targetRole == 'all_servants') {
              targetRoles = ['member', 'member_manager'];
            } else if (targetRole == 'member_managers') {
              targetRoles = ['member_manager'];
            } else if (targetRole == 'managers') {
              targetRoles = ['manager'];
            }

            // If stage-specific
            if (stage.isNotEmpty && stage != 'all') {
              targetStages = [stage];
            }

            await notificationService.createAutomaticNotification(
              sender: senderUserModel,
              type: 'attachment',
              title: 'New File',
              body: 'A new file was uploaded: $title',
              targetRoles: targetRoles,
              targetStages: targetStages,
              relatedId: docRef.id,
            );
          } catch (e) {
            debugPrint('[ATTACHMENT SERVICE] notification error: $e');
          }
        }
      } else {
        debugPrint(
          '[ATTACHMENT SERVICE] Cloudinary upload failed: ${response.statusCode} ${response.data}',
        );
        throw Exception('Cloudinary upload failed: ${response.statusCode}');
      }
    } catch (e, st) {
      debugPrint('[ATTACHMENT SERVICE] Upload error: $e');
      debugPrint(st.toString());
      rethrow;
    }
  }

  /// Upload file to Cloudinary and save metadata to Firestore
  /// Pass senderUserModel to trigger automatic notifications
  Future<void> uploadAttachment({
    required File file,
    required String fileName,
    required String title,
    required String stage,
    required String uploadedBy,
    required String targetRole,
    dynamic senderUserModel, // UserModel for notifications
    NotificationService? notificationService,
  }) async {
    try {
      final normalized = normalizeStage(stage);
      final fileSize = await file.length();

      debugPrint(
        '[ATTACHMENT SERVICE] Starting upload for fileName=$fileName, size=$fileSize bytes, targetRole=$targetRole',
      );

      const cloudinaryUrl =
          'https://api.cloudinary.com/v1_1/djniksauo/raw/upload';

      final multipart = await MultipartFile.fromFile(
        file.path,
        filename: fileName,
      );
      final formData = FormData.fromMap({
        'file': multipart,
        'upload_preset': 'summerschool',
      });

      debugPrint('[ATTACHMENT SERVICE] Cloudinary upload started (file)');

      final response = await _dio.post(
        cloudinaryUrl,
        data: formData,
        onSendProgress: (sent, total) {
          final progress = total > 0 ? (sent / total) * 100 : 0;
          debugPrint(
            '[ATTACHMENT SERVICE] UPLOAD PROGRESS: ${progress.toStringAsFixed(2)}%',
          );
        },
      );

      debugPrint(
        '[ATTACHMENT SERVICE] Cloudinary response status: ${response.statusCode}',
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        var fileUrl = response.data['secure_url'] as String? ?? '';
        // Add fl_attachment flag for proper content delivery/download
        fileUrl = fileUrl.replaceAll('/upload/', '/upload/fl_attachment/');
        debugPrint(
          '[ATTACHMENT SERVICE] Cloudinary secure_url (with fl_attachment): $fileUrl',
        );

        final docRef = _firestore.collection('attachments').doc();
        final attachmentData = AttachmentModel(
          id: docRef.id,
          title: title,
          fileName: fileName,
          fileUrl: fileUrl,
          fileSize: fileSize,
          uploadedBy: uploadedBy,
          targetStage: stage,
          stage_norm: normalized,
          targetRole: targetRole,
          createdAt: DateTime.now(),
        );

        await docRef.set(attachmentData.toMap());
        debugPrint(
          '[ATTACHMENT SERVICE] Attachment metadata saved to Firestore with id=${docRef.id}, targetRole=$targetRole',
        );

        // Trigger automatic notification
        if (senderUserModel != null && notificationService != null) {
          try {
            // Determine target recipients based on targetRole
            List<String> targetRoles = [];
            List<String> targetStages = [];

            if (targetRole == 'all_servants') {
              targetRoles = ['member', 'member_manager'];
            } else if (targetRole == 'member_managers') {
              targetRoles = ['member_manager'];
            } else if (targetRole == 'managers') {
              targetRoles = ['manager'];
            }

            // If stage-specific
            if (stage.isNotEmpty && stage != 'all') {
              targetStages = [stage];
            }

            await notificationService.createAutomaticNotification(
              sender: senderUserModel,
              type: 'attachment',
              title: 'New File',
              body: 'A new file was uploaded: $title',
              targetRoles: targetRoles,
              targetStages: targetStages,
              relatedId: docRef.id,
            );
          } catch (e) {
            debugPrint('[ATTACHMENT SERVICE] notification error: $e');
          }
        }
      } else {
        debugPrint(
          '[ATTACHMENT SERVICE] Cloudinary upload failed: ${response.statusCode} ${response.data}',
        );
        throw Exception('Cloudinary upload failed: ${response.statusCode}');
      }
    } catch (e, st) {
      debugPrint('[ATTACHMENT SERVICE] Upload error: $e');
      debugPrint(st.toString());
      rethrow;
    }
  }

  /// Delete attachment from Firestore only (files are hosted on Cloudinary)
  Future<void> deleteAttachment(AttachmentModel attachment) async {
    try {
      debugPrint(
        '[ATTACHMENT SERVICE] Deleting attachment id=${attachment.id}',
      );

      // Delete from Firestore only
      // (Cloudinary files are not deleted from code without Admin API key/secret)
      await _firestore.collection('attachments').doc(attachment.id).delete();

      debugPrint('[ATTACHMENT SERVICE] Attachment deleted from Firestore');
    } catch (e) {
      debugPrint('[ATTACHMENT SERVICE] Delete error: $e');
      rethrow;
    }
  }
}
