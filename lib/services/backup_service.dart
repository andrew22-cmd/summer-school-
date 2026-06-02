import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'backup_service_web.dart'
    if (dart.library.io) 'backup_service_web_stub.dart';

class BackupFileInfo {
  const BackupFileInfo({
    required this.fileName,
    required this.createdAt,
    required this.sizeBytes,
  });

  final String fileName;
  final DateTime createdAt;
  final int sizeBytes;

  String get filePath => fileName;
}

class BackupService {
  BackupService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const List<String> _collectionsToBackup = [
    'users',
    'class_members',
    'notifications',
    'user_notifications',
    'tasks',
    'attachments',
    'events',
    'visits',
    'followups',
    'attendance',
    'servants_attendance',
    'weekly_schedules',
    'spiritual_notes',
  ];

  Future<BackupFileInfo> createBackup() async {
    debugPrint('[BackupService] Starting backup...');

    final createdAt = DateTime.now();
    final fileName = _buildFileName(createdAt);

    final collections = <String, List<Map<String, dynamic>>>{};
    for (final collectionName in _collectionsToBackup) {
      final docs = await _readCollection(collectionName);
      collections[collectionName] = docs;
      debugPrint(
        '[BackupService] Collected $collectionName docs=${docs.length}',
      );
    }

    final payload = <String, dynamic>{
      'createdAt': createdAt.toIso8601String(),
      'appVersion': '1.0.0',
      'collections': collections,
    };

    final jsonString = const JsonEncoder.withIndent(
      '  ',
    ).convert(_jsonSafe(payload));
    final bytes = utf8.encode(jsonString);

    if (kIsWeb) {
      // Web: trigger browser download
      downloadBackupFile(fileName, bytes);
      debugPrint('[BackupService] Backup triggered for download: $fileName');
    } else {
      // Mobile/Desktop: save to local directory
      final dir = await _getBackupsDirectory();
      final file = io.File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);
      debugPrint('[BackupService] Backup saved: ${file.path}');
    }

    return BackupFileInfo(
      fileName: fileName,
      createdAt: createdAt,
      sizeBytes: bytes.length,
    );
  }

  Future<List<BackupFileInfo>> getBackups() async {
    if (kIsWeb) {
      // Web: can't list downloads folder
      debugPrint('[BackupService] Backups listing unavailable on web');
      return const [];
    }

    try {
      final dir = await _getBackupsDirectory(createIfMissing: false);
      if (!await dir.exists()) return const [];

      final files = await dir
          .list()
          .where((entity) => entity is io.File && entity.path.endsWith('.json'))
          .cast<io.File>()
          .toList();

      final infos = <BackupFileInfo>[];
      for (final file in files) {
        final stat = await file.stat();
        infos.add(
          BackupFileInfo(
            fileName: file.uri.pathSegments.last,
            createdAt: stat.modified,
            sizeBytes: stat.size,
          ),
        );
      }

      infos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return infos;
    } catch (e) {
      debugPrint('[BackupService] Error listing backups: $e');
      return const [];
    }
  }

  Future<void> deleteBackup(BackupFileInfo backup) async {
    if (kIsWeb) {
      debugPrint('[BackupService] Delete unavailable on web');
      return;
    }

    try {
      final dir = await _getBackupsDirectory(createIfMissing: false);
      final file = io.File('${dir.path}/${backup.fileName}');
      if (await file.exists()) {
        await file.delete();
        debugPrint('[BackupService] Deleted: ${file.path}');
      }
    } catch (e) {
      debugPrint('[BackupService] Error deleting backup: $e');
    }
  }

  Future<void> shareBackup(BackupFileInfo backup) async {
    if (kIsWeb) {
      debugPrint('[BackupService] Share unavailable on web');
      return;
    }

    try {
      final dir = await _getBackupsDirectory(createIfMissing: false);
      final file = io.File('${dir.path}/${backup.fileName}');
      if (await file.exists()) {
        await Share.shareXFiles([XFile(file.path)]);
        debugPrint('[BackupService] Shared: ${file.path}');
      }
    } catch (e) {
      debugPrint('[BackupService] Error sharing backup: $e');
    }
  }

  Future<io.Directory> _getBackupsDirectory({
    bool createIfMissing = true,
  }) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = io.Directory('${base.path}/backups');
    if (createIfMissing && !await dir.exists()) {
      await dir.create(recursive: true);
      debugPrint('[BackupService] Created folder: ${dir.path}');
    }
    return dir;
  }

  String _buildFileName(DateTime dateTime) {
    String two(int value) => value.toString().padLeft(2, '0');
    return 'backup_${dateTime.year}_${two(dateTime.month)}_${two(dateTime.day)}_${two(dateTime.hour)}_${two(dateTime.minute)}_${two(dateTime.second)}.json';
  }

  Future<List<Map<String, dynamic>>> _readCollection(String name) async {
    debugPrint('[BackupService] Reading collection: $name');
    final result = <Map<String, dynamic>>[];
    DocumentSnapshot<Map<String, dynamic>>? lastDoc;

    while (true) {
      Query<Map<String, dynamic>> query = _firestore
          .collection(name)
          .limit(500);
      if (lastDoc != null) {
        query = query.startAfterDocument(lastDoc);
      }

      final snapshot = await query.get();
      if (snapshot.docs.isEmpty) break;

      for (final doc in snapshot.docs) {
        result.add({'id': doc.id, ..._jsonSafe(doc.data())});
      }

      lastDoc = snapshot.docs.last;
      if (snapshot.docs.length < 500) break;
    }

    return result;
  }

  dynamic _jsonSafe(dynamic value) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    if (value is DateTime) {
      return value.toIso8601String();
    }
    if (value is Timestamp) {
      return value.toDate().toIso8601String();
    }
    if (value is GeoPoint) {
      return {'latitude': value.latitude, 'longitude': value.longitude};
    }
    if (value is DocumentReference) {
      return value.path;
    }
    if (value is Map) {
      return value.map((key, v) => MapEntry(key.toString(), _jsonSafe(v)));
    }
    if (value is Iterable) {
      return value.map(_jsonSafe).toList();
    }
    return value.toString();
  }
}
