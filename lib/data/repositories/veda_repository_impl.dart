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
/// from `secrets/local.env` — never hardcoded, never committed.
class VedaRepositoryImpl implements VedaRepository {
  VedaRepositoryImpl(this._dao, {http.Client? client})
      : _client = client ?? http.Client();

  final ChatDao _dao;
  final http.Client _client;

  static const String _endpoint =
      'https://api.groq.com/openai/v1/chat/completions';
  static const String _model = 'llama-3.3-70b-versatile';
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
    if (_apiKey.isEmpty) throw const VedaUnavailableException();
    final body = jsonEncode({
      'model': _model,
      'temperature': 0.4,
      'max_tokens': 512,
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
      final choices = decoded['choices'] as List<dynamic>;
      final content = ((choices.first as Map<String, dynamic>)['message']
          as Map<String, dynamic>)['content'] as String?;
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
