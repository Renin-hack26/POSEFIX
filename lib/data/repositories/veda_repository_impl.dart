import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

import '../../../core/errors/app_exception.dart';
import '../../../domain/entities/chat_message.dart';
import '../../../domain/repositories/veda_repository.dart';
import '../datasources/local/chat_dao.dart';

/// VEDA chat — local history (account-synced via the sweep) + GROQ transport.
///
/// The API key is injected at build time (`--dart-define=GROQ_API_KEY=...`)
/// from `secrets/local.env` — never hardcoded, never committed. Model:
/// `openai/gpt-oss-120b`.
class VedaRepositoryImpl implements VedaRepository {
  VedaRepositoryImpl(this._dao, {http.Client? client})
      : _client = client ?? http.Client();

  final ChatDao _dao;
  final http.Client _client;

  static const String _endpoint =
      'https://api.groq.com/openai/v1/chat/completions';
  static const String _model = 'openai/gpt-oss-120b';
  static const String _apiKey = String.fromEnvironment('GROQ_API_KEY');

  @override
  Future<List<ChatMessage>> history() => _dao.all();

  @override
  Future<void> saveMessage(ChatMessage message) => _dao.upsert(message);

  @override
  Future<void> clearHistory() => _dao.clear();

  @override
  Future<String> complete({
    required List<ChatMessage> turns,
    required String systemPrompt,
  }) async {
    if (_apiKey.isEmpty) {
      throw const VedaUnavailableException('API key not configured for this build');
    }
    final body = jsonEncode({
      'model': _model,
      'temperature': 0.4,
      'max_tokens': 1024,
      'reasoning_effort': 'low',
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        for (final t in turns)
          {
            'role': t.role == ChatRole.user ? 'user' : 'assistant',
            'content': t.text,
          },
      ],
    });
    try {
      final response = await _client
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Authorization': 'Bearer $_apiKey',
              'Content-Type': 'application/json',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        debugPrint('VEDA transport HTTP ${response.statusCode}');
        throw const VedaUnavailableException();
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
      // Malformed success shapes (empty choices, unexpected types) are a
      // server-contract failure, not a connectivity problem — label them
      // so the UI takes the assistant-down path instead of retry-as-offline.
      final choices = decoded['choices'];
      if (choices is! List<dynamic> || choices.isEmpty) {
        throw const VedaUnavailableException();
      }
      final first = choices.first;
      if (first is! Map<String, dynamic>) {
        throw const VedaUnavailableException();
      }
      final message = first['message'];
      if (message is! Map<String, dynamic>) {
        throw const VedaUnavailableException();
      }
      final content = message['content'] as String?;
      if (content == null || content.trim().isEmpty) {
        throw const VedaUnavailableException();
      }
      return content.trim();
    } on AppException {
      rethrow;
    } catch (_) {
      throw const NetworkException();
    }
  }
}
