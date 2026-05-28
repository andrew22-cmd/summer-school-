import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class GitHubTriggerService {
  GitHubTriggerService({
    String githubToken = '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',
    String repoOwner = 'andrew22-cmd',
    String repoName = 'summer-school-',
    this.workflowFile = 'send_notification.yml',
    this.ref = 'main',
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
    String? topic,
    String? token,
  }) async {
    return sendNotification(
      title: title,
      body: body,
      topic: topic,
      token: token,
    );
  }

  Future<bool> sendNotification({
    required String title,
    required String body,
    String? topic,
    String? token,
  }) async {
    if (_hasPlaceholderCredentials()) {
      debugPrint(
        '[GitHubTrigger] Placeholder credentials detected. Skipping dispatch.',
      );
      return false;
    }

    final tokenValid =
        _githubToken.isNotEmpty && !_githubToken.startsWith('YOUR_');
    debugPrint(
      '[GitHubTrigger] Token valid: $tokenValid, length=${_githubToken.length}, prefix=${_githubToken.substring(0, 4)}***',
    );
    debugPrint('[GitHubTrigger] Repo: $_repoOwner/$_repoName');
    debugPrint('[GitHubTrigger] Workflow file: $workflowFile');
    debugPrint('[GitHubTrigger] Target branch/ref: $ref');

    final url = Uri.parse(
      'https://api.github.com/repos/$_repoOwner/$_repoName/actions/workflows/$workflowFile/dispatches',
    );

    final payload = <String, dynamic>{
      'ref': ref,
      'inputs': <String, dynamic>{
        'title': title,
        'body': body,
        if (topic != null && topic.trim().isNotEmpty) 'topic': topic.trim(),
        if (token != null && token.trim().isNotEmpty) 'token': token.trim(),
      },
    };

    try {
      final hasToken = token != null && token.trim().isNotEmpty;
      debugPrint('[GitHubTrigger] Dispatch start');
      debugPrint('[GitHubTrigger] Dispatching workflow: $url');
      debugPrint(
        '[GitHubTrigger] target=${hasToken ? 'token' : 'topic'} topic=${topic?.trim().isNotEmpty == true ? topic!.trim() : '[none]'} token=${hasToken ? '[provided]' : '[none]'} ref=$ref',
      );
      debugPrint('[GitHubTrigger] workflow payload: ${jsonEncode(payload)}');

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
      debugPrint('[GitHubTrigger] Response body: ${response.body}');
      debugPrint('[GitHubTrigger] Response headers: ${response.headers}');

      if (response.statusCode == 204) {
        debugPrint(
          '[GitHubTrigger] Workflow dispatched successfully to branch $ref',
        );
        return true;
      }

      if (response.statusCode == 401) {
        debugPrint(
          '[GitHubTrigger] AUTHENTICATION FAILED (401) - Token may be expired or invalid',
        );
      } else if (response.statusCode == 404) {
        debugPrint(
          '[GitHubTrigger] NOT FOUND (404) - Check: repo name, workflow file name, or branch "$ref" does not exist',
        );
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

    if (normalizedRole == 'manager') return 'all';
    if (normalizedRole == 'member_manager') return 'member_managers';
    if (normalizedRole == 'member') return 'members';
    if (sanitizedStage != null && sanitizedStage.isNotEmpty) {
      return sanitizedStage;
    }
    if (normalizedRole.isNotEmpty) return normalizedRole;
    return 'all';
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
