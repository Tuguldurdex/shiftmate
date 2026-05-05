import 'dart:convert';
import 'package:http/http.dart' as http;
import '../features/group_chat/domain/chat_message.dart';

class OllamaService {
  static const String defaultBaseUrl = '';
  static const List<String> availableModels = [
    'llama3',
    'llama2',
    'mistral',
    'codellama',
    'phi3',
    'gemma',
    'llama3.1',
    'llama3.2',
  ];

  String baseUrl;

  OllamaService({String? baseUrl}) : baseUrl = baseUrl ?? defaultBaseUrl;

  Future<bool> checkConnection() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/tags'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<OllamaResponse> chat({
    required String model,
    required List<OllamaMessage> messages,
    required String systemPrompt,
    double temperature = 0.7,
  }) async {
    if (baseUrl.isEmpty) {
      return OllamaResponse(
        content: 'Ollama server URL is not configured. Please set it in AI Settings.',
        model: model,
        responseTimeMs: 0,
        success: false,
        error: 'Base URL is empty',
      );
    }

    final startTime = DateTime.now();

    final ollamaMessages = [
      OllamaMessage(role: 'system', content: systemPrompt),
      ...messages,
    ];

    // Try /api/chat first (newer Ollama versions)
    final chatBody = {
      'model': model,
      'messages': ollamaMessages.map((m) => m.toJson()).toList(),
      'stream': false,
      'options': {
        'temperature': temperature,
      },
    };

    try {
      var response = await http
          .post(
            Uri.parse('$baseUrl/api/chat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(chatBody),
          )
          .timeout(const Duration(seconds: 60));

      // If /api/chat returns 404, try /api/generate (older Ollama versions)
      if (response.statusCode == 404) {
        final prompt = ollamaMessages
            .map((m) => '${m.role}: ${m.content}')
            .join('\n');
        
        final generateBody = {
          'model': model,
          'prompt': prompt,
          'system': systemPrompt,
          'stream': false,
          'options': {
            'temperature': temperature,
          },
        };

        response = await http
            .post(
              Uri.parse('$baseUrl/api/generate'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(generateBody),
            )
            .timeout(const Duration(seconds: 60));
      }

      final elapsed = DateTime.now().difference(startTime).inMilliseconds;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        
        // Handle /api/chat response format
        String content;
        if (data.containsKey('message')) {
          final messageData = data['message'] as Map<String, dynamic>?;
          content = messageData?['content'] as String? ?? '';
        } else {
          // Handle /api/generate response format
          content = data['response'] as String? ?? '';
        }
        
        final promptEvalCount = data['prompt_eval_count'] as int?;
        final evalCount = data['eval_count'] as int?;

        return OllamaResponse(
          content: content,
          model: model,
          responseTimeMs: elapsed,
          tokenCount: (promptEvalCount ?? 0) + (evalCount ?? 0),
          success: true,
        );
      } else {
        return OllamaResponse(
          content: 'AI is unavailable (HTTP ${response.statusCode}). Check Ollama server.',
          model: model,
          responseTimeMs: elapsed,
          success: false,
          error: 'HTTP ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      return OllamaResponse(
        content: 'Cannot reach Ollama server at $baseUrl.\n\nMake sure:\n• Ollama is running on your computer\n• Your phone and computer are on the same WiFi\n• Use your computer\'s local IP (not localhost)',
        model: model,
        responseTimeMs: elapsed,
        success: false,
        error: e.toString(),
      );
    }
  }

  Future<String> summarizeMessages({
    required String model,
    required List<ChatMessage> messages,
    double temperature = 0.3,
  }) async {
    final chatHistory = messages.map((m) {
      return OllamaMessage(
        role: m.senderName,
        content: '${m.senderName}: ${m.messageText}',
      );
    }).toList();

    final result = await chat(
      model: model,
      messages: chatHistory,
      systemPrompt: 'Summarize the following group chat conversation concisely. Highlight key points and decisions made.',
      temperature: temperature,
    );

    return result.content;
  }

  Future<String> extractActionItems({
    required String model,
    required List<ChatMessage> messages,
    double temperature = 0.3,
  }) async {
    final chatHistory = messages.map((m) {
      return OllamaMessage(
        role: m.senderName,
        content: '${m.senderName}: ${m.messageText}',
      );
    }).toList();

    final result = await chat(
      model: model,
      messages: chatHistory,
      systemPrompt: 'Extract all action items from the following conversation. Format each as a bullet point with the responsible person if mentioned.',
      temperature: temperature,
    );

    return result.content;
  }

  Future<String> translateMessage({
    required String model,
    required String text,
    required String targetLanguage,
    double temperature = 0.3,
  }) async {
    final result = await chat(
      model: model,
      messages: [OllamaMessage(role: 'user', content: text)],
      systemPrompt: 'Translate the following text to $targetLanguage. Only output the translation.',
      temperature: temperature,
    );

    return result.content;
  }

  Future<String> draftContent({
    required String model,
    required String topic,
    double temperature = 0.7,
  }) async {
    final result = await chat(
      model: model,
      messages: [OllamaMessage(role: 'user', content: 'Draft a message about: $topic')],
      systemPrompt: 'You are a helpful assistant. Draft professional, clear content for a workplace group chat.',
      temperature: temperature,
    );

    return result.content;
  }
}

class OllamaMessage {
  final String role;
  final String content;

  OllamaMessage({required this.role, required this.content});

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

class OllamaResponse {
  final String content;
  final String model;
  final int responseTimeMs;
  final int tokenCount;
  final bool success;
  final String? error;

  OllamaResponse({
    required this.content,
    required this.model,
    required this.responseTimeMs,
    this.tokenCount = 0,
    this.success = true,
    this.error,
  });
}
