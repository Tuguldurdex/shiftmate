import 'dart:convert';
import 'package:http/http.dart' as http;
import '../features/group_chat/domain/chat_message.dart';

class AnthropicService {
  static const String apiEndpoint = 'https://api.anthropic.com/v1/messages';
  static const String model = 'claude-sonnet-4-20250514';
  static const String anthropicVersion = '2023-06-01';

  String apiKey;

  AnthropicService({String? apiKey}) : apiKey = apiKey ?? '';

  Future<bool> checkConnection() async {
    return apiKey.isNotEmpty;
  }

  Future<AnthropicResponse> chat({
    required List<AnthropicMessage> messages,
    required String systemPrompt,
    double temperature = 0.7,
  }) async {
    if (apiKey.isEmpty) {
      return AnthropicResponse(
        content:
            'Anthropic API key is not configured. Please set it in AI Settings.',
        model: model,
        responseTimeMs: 0,
        success: false,
        error: 'API key is empty',
      );
    }

    final startTime = DateTime.now();

    final body = {
      'model': model,
      'system': systemPrompt,
      'messages': messages.map((m) => m.toJson()).toList(),
      'temperature': temperature,
      'max_tokens': 4096,
    };

    try {
      final response = await http
          .post(
            Uri.parse(apiEndpoint),
            headers: {
              'Content-Type': 'application/json',
              'x-api-key': apiKey,
              'anthropic-version': anthropicVersion,
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 60));

      final elapsed = DateTime.now().difference(startTime).inMilliseconds;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final content = _extractContent(data);
        final inputTokens = data['usage']?['input_tokens'] as int? ?? 0;
        final outputTokens = data['usage']?['output_tokens'] as int? ?? 0;

        return AnthropicResponse(
          content: content,
          model: model,
          responseTimeMs: elapsed,
          tokenCount: inputTokens + outputTokens,
          success: true,
        );
      } else {
        return AnthropicResponse(
          content:
              'AI is unavailable (HTTP ${response.statusCode}). Check API key.',
          model: model,
          responseTimeMs: elapsed,
          success: false,
          error: 'HTTP ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      return AnthropicResponse(
        content:
            'Cannot reach Anthropic API.\n\nMake sure:\n• You have a valid API key\n• You have internet connectivity',
        model: model,
        responseTimeMs: elapsed,
        success: false,
        error: e.toString(),
      );
    }
  }

  String _extractContent(Map<String, dynamic> data) {
    final content = data['content'] as List?;
    if (content != null && content.isNotEmpty) {
      final firstContent = content.first as Map<String, dynamic>;
      return firstContent['text'] as String? ?? '';
    }
    return '';
  }

  Future<String> summarizeMessages({
    required List<ChatMessage> messages,
    double temperature = 0.3,
  }) async {
    final chatHistory = messages.map((m) {
      return AnthropicMessage(
        role: m.senderName == 'AI Assistant' ? 'assistant' : 'user',
        content: '${m.senderName}: ${m.messageText}',
      );
    }).toList();

    final result = await chat(
      messages: chatHistory,
      systemPrompt:
          'Summarize the following group chat conversation concisely. Highlight key points and decisions made.',
      temperature: temperature,
    );

    return result.content;
  }

  Future<String> extractActionItems({
    required List<ChatMessage> messages,
    double temperature = 0.3,
  }) async {
    final chatHistory = messages.map((m) {
      return AnthropicMessage(
        role: m.senderName == 'AI Assistant' ? 'assistant' : 'user',
        content: '${m.senderName}: ${m.messageText}',
      );
    }).toList();

    final result = await chat(
      messages: chatHistory,
      systemPrompt:
          'Extract all action items from the following conversation. Format each as a bullet point with the responsible person if mentioned.',
      temperature: temperature,
    );

    return result.content;
  }

  Future<String> translateMessage({
    required String text,
    required String targetLanguage,
    double temperature = 0.3,
  }) async {
    final result = await chat(
      messages: [AnthropicMessage(role: 'user', content: text)],
      systemPrompt:
          'Translate the following text to $targetLanguage. Only output the translation.',
      temperature: temperature,
    );

    return result.content;
  }

  Future<String> draftContent({
    required String topic,
    double temperature = 0.7,
  }) async {
    final result = await chat(
      messages: [
        AnthropicMessage(
          role: 'user',
          content: 'Draft a message about: $topic',
        ),
      ],
      systemPrompt:
          'You are a helpful assistant. Draft professional, clear content for a workplace group chat.',
      temperature: temperature,
    );

    return result.content;
  }
}

class AnthropicMessage {
  final String role;
  final String content;

  AnthropicMessage({required this.role, required this.content});

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

class AnthropicResponse {
  final String content;
  final String model;
  final int responseTimeMs;
  final int tokenCount;
  final bool success;
  final String? error;

  AnthropicResponse({
    required this.content,
    required this.model,
    this.responseTimeMs = 0,
    this.tokenCount = 0,
    this.success = true,
    this.error,
  });
}
