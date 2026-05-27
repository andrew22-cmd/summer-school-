import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class GitHubTriggerService {
  GitHubTriggerService({
    String githubToken = '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',
    String repoOwner = 'andrew22-cmd',
    String repoName = 'summer-school-',
    this.workflowFile = 'send_notification.yml',
    this.ref = 'version2',
    http.Client? client,
  }) : _githubToken = githubToken,
       _repoOwner = repoOwner,
       _repoName = repoName,
       _client = client ?? http.Client();

  final String _githubToken;
  final String _repoOwner;
  final String _repoName;
  final String workflowFile;
  final String ref;
  final http.Client _client;

  Future<bool> triggerNotification({
    required String title,
    required String body,
    required String topic,
  }) async {
    if (_hasPlaceholderCredentials()) {
      debugPrint(
        '[GitHubTrigger] Placeholder credentials detected. Skipping dispatch.',
      );
      return false;
    }

    final url = Uri.parse(
      'https://api.github.com/repos/$_repoOwner/$_repoName/actions/workflows/$workflowFile/dispatches',
    );

    final payload = <String, dynamic>{
      'ref': ref,
      'inputs': <String, dynamic>{'title': title, 'body': body, 'topic': topic},
    };

    try {
      debugPrint('[GitHubTrigger] Dispatching workflow: $url');
      debugPrint('[GitHubTrigger] ref=$ref topic=$topic');

      final response = await _client.post(
        url,
        headers: <String, String>{
          'Accept': 'application/vnd.github+json',
          'Authorization': 'Bearer $_githubToken',
          'X-GitHub-Api-Version': '2022-11-28',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      debugPrint('[GitHubTrigger] Status: ${response.statusCode}');
      debugPrint('[GitHubTrigger] Response: ${response.body}');

      if (response.statusCode == 204) {
        debugPrint('[GitHubTrigger] Workflow dispatched successfully');
        return true;
      }

      throw Exception(
        'GitHub dispatch failed (${response.statusCode}): ${response.body}',
      );
    } catch (error) {
      debugPrint('[GitHubTrigger] Error: $error');
      rethrow;
    }
  }

  String resolveTopic({required String role, String? stage}) {
    final normalizedRole = role.trim().toLowerCase();
    final sanitizedStage = _sanitizeStage(stage);

    if (normalizedRole == 'manager') return 'all_users';
    if (sanitizedStage != null && sanitizedStage.isNotEmpty) {
      return sanitizedStage;
    }
    if (normalizedRole.isNotEmpty) return normalizedRole;
    return 'all_users';
  }

  String? _sanitizeStage(String? stage) {
    if (stage == null) return null;

    final cleaned = stage.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9_]'),
      '_',
    );
    if (cleaned.isEmpty) return null;

    if (cleaned.startsWith('stage_')) return cleaned;
    return 'stage_$cleaned';
  }

  bool _hasPlaceholderCredentials() {
    return _repoOwner.startsWith('YOUR_') ||
        _repoName.startsWith('YOUR_') ||
        _githubToken.startsWith('YOUR_');
  }
}
