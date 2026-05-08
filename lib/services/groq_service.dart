import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class GroqService {
  static const String _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static const String _model = 'llama3-8b-8192';

  String? get _apiKey => dotenv.env['GROQ_API_KEY'];

  Future<GroqResponse> chat({
    required List<GroqMessage> messages,
    double temperature = 0.7,
  }) async {
    final apiKey = _apiKey;
    if (apiKey == null || !apiKey.startsWith('gsk_')) {
      return GroqResponse(
        content: 'AI is unavailable right now. API key not configured.',
        success: false,
        error: 'Missing or invalid GROQ_API_KEY in .env file',
      );
    }

    final startTime = DateTime.now();

    try {
      final response = await http
          .post(
            Uri.parse(_baseUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode({
              'model': _model,
              'messages': messages.map((m) => m.toJson()).toList(),
              'temperature': temperature,
              'stream': false,
            }),
          )
          .timeout(const Duration(seconds: 30));

      final elapsed = DateTime.now().difference(startTime).inMilliseconds;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final choices = data['choices'] as List?;
        if (choices != null && choices.isNotEmpty) {
          final message = choices[0]['message'] as Map<String, dynamic>;
          final content = message['content'] as String? ?? '';
          return GroqResponse(
            content: content,
            model: _model,
            responseTimeMs: elapsed,
            success: true,
          );
        }
        return GroqResponse(
          content: 'AI is unavailable right now.',
          responseTimeMs: elapsed,
          success: false,
          error: 'No choices in response',
        );
      } else {
        return GroqResponse(
          content: 'AI is unavailable right now.',
          responseTimeMs: elapsed,
          success: false,
          error: 'HTTP ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      return GroqResponse(
        content: 'AI is unavailable right now.',
        responseTimeMs: elapsed,
        success: false,
        error: e.toString(),
      );
    }
  }
}

class GroqMessage {
  final String role; // 'system', 'user', or 'assistant'
  final String content;

  GroqMessage({required this.role, required this.content});

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
      };
}

class GroqResponse {
  final String content;
  final String? model;
  final int? responseTimeMs;
  final bool success;
  final String? error;

  GroqResponse({
    required this.content,
    this.model,
    this.responseTimeMs,
    required this.success,
    this.error,
  });
}
