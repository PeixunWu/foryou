import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/ai_config.dart';

/// Image payload for vision requests (OpenAI-compatible base64 encoding).
class AiImagePart {
  const AiImagePart(this.bytes, {this.mimeType = 'image/jpeg'});

  final Uint8List bytes;
  final String mimeType;

  String get dataUrl => 'data:$mimeType;base64,${base64Encode(bytes)}';
}

/// Chat turn for multi-turn coach conversations.
class AiChatTurn {
  const AiChatTurn({required this.role, required this.text});

  final String role; // user | assistant | model
  final String text;
}

/// Unified AI request routed through the fallback pipeline.
class AiRequest {
  const AiRequest({
    required this.prompt,
    this.images = const [],
    this.systemInstruction,
    this.chatHistory = const [],
  });

  final String prompt;
  final List<AiImagePart> images;
  final String? systemInstruction;
  final List<AiChatTurn> chatHistory;

  bool get isVision => images.isNotEmpty;
}

/// High-resiliency sequential fallback: Gemini 3 → Gemini 1.5 (old key) → Groq → OpenRouter.
class AiFallbackManager {
  AiFallbackManager({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _geminiBase =
      'https://generativelanguage.googleapis.com/v1beta';
  static const String _groqUrl =
      'https://api.groq.com/openai/v1/chat/completions';
  static const String _openRouterUrl =
      'https://openrouter.ai/api/v1/chat/completions';

  static const String gemini3Model = 'gemini-3-flash-preview';
  static const String gemini15Model = 'gemini-1.5-flash';

  static const String groqVisionModel = 'llama-3.2-11b-vision-preview';
  static const String groqTextModel = 'llama-3.3-70b-versatile';

  static const String openRouterVisionModel = 'google/gemma-4-31b-it:free';
  static const String openRouterTextModel = 'deepseek/deepseek-v4-flash:free';

  /// Runs PRIMARY → FALLBACK 1 → 2 → 3. Never throws to callers; returns
  /// [fallbackMessage] when every provider fails (keeps UI stable).
  Future<String> complete(
    AiRequest request, {
    String fallbackMessage = 'AI is temporarily unavailable. Please try again shortly.',
  }) async {
    try {
      // PRIMARY: Gemini 3
      if (AiConfig.hasPrimaryGemini) {
        try {
          final text = await _tryGemini(
            apiKey: AiConfig.geminiApiKey,
            model: gemini3Model,
            request: request,
            label: 'PRIMARY Gemini 3',
          );
          if (text != null && text.isNotEmpty) return text;
        } catch (e, st) {
          debugPrint('⚠️ PRIMARY Gemini 3 failed: $e');
          if (kDebugMode) debugPrint('$st');
        }
      } else {
        debugPrint('⚠️ GEMINI_API_KEY not set; skipping PRIMARY.');
      }

      // FALLBACK 1: Gemini 1.5 Flash (legacy Google key)
      if (AiConfig.hasLegacyGemini) {
        try {
          final text = await _tryGemini(
            apiKey: AiConfig.geminiOldKey,
            model: gemini15Model,
            request: request,
            label: 'FALLBACK 1 Gemini 1.5 Flash',
          );
          if (text != null && text.isNotEmpty) return text;
        } catch (e, st) {
          debugPrint('⚠️ FALLBACK 1 Gemini 1.5 failed: $e');
          if (kDebugMode) debugPrint('$st');
        }
      } else {
        debugPrint('⚠️ GEMINI_OLD_KEY not set; skipping FALLBACK 1.');
      }

      // FALLBACK 2: Groq
      if (AiConfig.hasGroq) {
        try {
          final text = await _tryGroq(request);
          if (text != null && text.isNotEmpty) return text;
        } catch (e, st) {
          debugPrint('⚠️ FALLBACK 2 Groq failed: $e');
          if (kDebugMode) debugPrint('$st');
        }
      } else {
        debugPrint('⚠️ GROQ_API_KEY not set; skipping FALLBACK 2.');
      }

      // FALLBACK 3: OpenRouter (free models)
      if (AiConfig.hasOpenRouter) {
        try {
          final text = await _tryOpenRouter(request);
          if (text != null && text.isNotEmpty) return text;
        } catch (e, st) {
          debugPrint('⚠️ FALLBACK 3 OpenRouter failed: $e');
          if (kDebugMode) debugPrint('$st');
        }
      } else {
        debugPrint('⚠️ OPENROUTER_API_KEY not set; skipping FALLBACK 3.');
      }
    } catch (e, st) {
      debugPrint('❌ AiFallbackManager unexpected error: $e');
      if (kDebugMode) debugPrint('$st');
    }

    debugPrint('❌ All AI providers exhausted; returning safe fallback text.');
    return fallbackMessage;
  }

  // --- Gemini (Google generateContent) ---

  Future<String?> _tryGemini({
    required String apiKey,
    required String model,
    required AiRequest request,
    required String label,
  }) async {
    final uri = Uri.parse(
      '$_geminiBase/models/$model:generateContent?key=$apiKey',
    );

    final body = <String, dynamic>{
      'contents': _buildGeminiContents(request),
    };

    if (request.systemInstruction != null &&
        request.systemInstruction!.isNotEmpty) {
      body['systemInstruction'] = {
        'role': 'user',
        'parts': [
          {'text': request.systemInstruction},
        ],
      };
    }

    debugPrint('🔮 $label → $model');
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    final decoded = _decodeJson(response.body);
    if (response.statusCode == 200 && decoded != null) {
      final text = _extractGeminiText(decoded);
      if (text != null && text.isNotEmpty) {
        debugPrint('✅ $label succeeded');
        return text;
      }
      throw AiProviderException(
        provider: label,
        statusCode: response.statusCode,
        message: 'Empty Gemini response',
      );
    }

    final error = decoded?['error'];
    final message = error is Map ? (error['message'] as String?) : null;
    final code = error is Map ? (error['status'] as String?) : null;

    throw AiProviderException(
      provider: label,
      statusCode: response.statusCode,
      code: code,
      message: message ?? response.body,
      isRateLimited: _isRateLimited(response.statusCode, code, message),
    );
  }

  List<Map<String, dynamic>> _buildGeminiContents(AiRequest request) {
    if (request.chatHistory.isNotEmpty) {
      final contents = <Map<String, dynamic>>[];
      for (final turn in request.chatHistory) {
        final role = turn.role == 'assistant' || turn.role == 'model'
            ? 'model'
            : 'user';
        if (turn.text.isEmpty) continue;
        contents.add({
          'role': role,
          'parts': [
            {'text': turn.text},
          ],
        });
      }
      contents.add({
        'role': 'user',
        'parts': [
          {'text': request.prompt},
        ],
      });
      return contents;
    }

    final parts = <Map<String, dynamic>>[];
    for (final image in request.images) {
      parts.add({
        'inlineData': {
          'data': base64Encode(image.bytes),
          'mimeType': image.mimeType,
        },
      });
    }
    parts.add({'text': request.prompt});
    return [
      {'role': 'user', 'parts': parts},
    ];
  }

  String? _extractGeminiText(Map<String, dynamic> json) {
    final candidates = json['candidates'];
    if (candidates is! List || candidates.isEmpty) return null;
    final content = candidates.first['content'];
    if (content is! Map<String, dynamic>) return null;
    final parts = content['parts'];
    if (parts is! List) return null;
    final buffer = StringBuffer();
    for (final part in parts) {
      if (part is Map<String, dynamic>) {
        final text = part['text'];
        if (text is String && text.isNotEmpty) buffer.write(text);
      }
    }
    final result = buffer.toString();
    return result.isEmpty ? null : result;
  }

  // --- Groq (OpenAI-compatible) ---

  Future<String?> _tryGroq(AiRequest request) async {
    final model = request.isVision ? groqVisionModel : groqTextModel;
    final body = {
      'model': model,
      'messages': _buildOpenAiMessages(request),
      'temperature': 0.4,
    };

    debugPrint('🔮 FALLBACK 2 Groq → $model');
    final response = await _client.post(
      Uri.parse(_groqUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${AiConfig.groqApiKey}',
      },
      body: jsonEncode(body),
    );

    return _parseOpenAiCompatibleResponse(
      response,
      providerLabel: 'Groq',
    );
  }

  // --- OpenRouter (OpenAI-compatible + required headers) ---

  Future<String?> _tryOpenRouter(AiRequest request) async {
    final model =
        request.isVision ? openRouterVisionModel : openRouterTextModel;
    final body = {
      'model': model,
      'messages': _buildOpenAiMessages(request),
      'temperature': 0.4,
    };

    debugPrint('🔮 FALLBACK 3 OpenRouter → $model');
    final response = await _client.post(
      Uri.parse(_openRouterUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${AiConfig.openRouterApiKey}',
        'HTTP-Referer': AiConfig.openRouterReferer,
        'X-Title': AiConfig.openRouterTitle,
      },
      body: jsonEncode(body),
    );

    return _parseOpenAiCompatibleResponse(
      response,
      providerLabel: 'OpenRouter',
    );
  }

  List<Map<String, dynamic>> _buildOpenAiMessages(AiRequest request) {
    final messages = <Map<String, dynamic>>[];

    if (request.systemInstruction != null &&
        request.systemInstruction!.isNotEmpty) {
      messages.add({
        'role': 'system',
        'content': request.systemInstruction,
      });
    }

    for (final turn in request.chatHistory) {
      final role = turn.role == 'model' ? 'assistant' : turn.role;
      if (turn.text.isEmpty) continue;
      messages.add({'role': role, 'content': turn.text});
    }

    if (request.isVision) {
      final content = <Map<String, dynamic>>[
        {'type': 'text', 'text': request.prompt},
      ];
      for (final image in request.images) {
        content.add({
          'type': 'image_url',
          'image_url': {'url': image.dataUrl},
        });
      }
      messages.add({'role': 'user', 'content': content});
    } else if (request.chatHistory.isEmpty) {
      messages.add({'role': 'user', 'content': request.prompt});
    } else if (request.prompt.isNotEmpty) {
      messages.add({'role': 'user', 'content': request.prompt});
    }

    return messages;
  }

  Future<String?> _parseOpenAiCompatibleResponse(
    http.Response response, {
    required String providerLabel,
  }) async {
    final decoded = _decodeJson(response.body);

    if (response.statusCode == 200 && decoded != null) {
      final choices = decoded['choices'];
      if (choices is List && choices.isNotEmpty) {
        final message = choices.first['message'];
        if (message is Map<String, dynamic>) {
          final content = message['content'];
          if (content is String && content.isNotEmpty) {
            debugPrint('✅ $providerLabel succeeded');
            return content;
          }
        }
      }
      throw AiProviderException(
        provider: providerLabel,
        statusCode: response.statusCode,
        message: 'Empty $providerLabel response',
      );
    }

    final error = decoded?['error'];
    String? message;
    String? code;
    if (error is Map<String, dynamic>) {
      message = error['message'] as String?;
      code = error['code'] as String? ?? error['type'] as String?;
    } else if (error is String) {
      message = error;
    }

    throw AiProviderException(
      provider: providerLabel,
      statusCode: response.statusCode,
      code: code,
      message: message ?? response.body,
      isRateLimited: _isRateLimited(response.statusCode, code, message),
    );
  }

  Map<String, dynamic>? _decodeJson(String body) {
    if (body.isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  static bool _isRateLimited(int statusCode, String? code, String? message) {
    if (statusCode == 429) return true;
    final c = code?.toUpperCase() ?? '';
    if (c.contains('RESOURCE_EXHAUSTED') ||
        c.contains('RATE_LIMIT') ||
        c.contains('QUOTA')) {
      return true;
    }
    final m = message?.toLowerCase() ?? '';
    return m.contains('rate limit') ||
        m.contains('quota') ||
        m.contains('too many requests') ||
        m.contains('tokens per minute') ||
        m.contains('tpm');
  }
}

class AiProviderException implements Exception {
  AiProviderException({
    required this.provider,
    required this.statusCode,
    this.code,
    required this.message,
    this.isRateLimited = false,
  });

  final String provider;
  final int statusCode;
  final String? code;
  final String message;
  final bool isRateLimited;

  @override
  String toString() =>
      'AiProviderException($provider, $statusCode, $code, $message)';
}
