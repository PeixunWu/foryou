import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/gemini_config.dart';

/// Gemini HTTP client with model fallback (Gemini 3 → 1.5 Flash → 1.5 Flash‑Lite).
class GeminiService {
  GeminiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _apiBase =
      'https://generativelanguage.googleapis.com/v1beta';

  /// Model fallback chain: Try Gemini 3 first, then fallback to 1.5 Flash variants.
  static const String primaryModel = 'gemini-3-flash-preview';
  static const String fallbackModel1 = 'gemini-1.5-flash';
  static const String fallbackModel2 = 'gemini-1.5-flash-8b'; // Flash-Lite

  /// Analyze a pill/medicine from image bytes.
  /// Prefer high-resolution capture for box fine print.
  ///
  /// Uses Gemini 3 first; if rate-limited or quota-exhausted, falls back to
  /// Gemini 1.5 Flash, then 1.5 Flash‑Lite without breaking UX.
  Future<ScanAnalysis> analyzePill(
      Uint8List imageBytes, String? userSkinProfile) async {
    final prompt = '''
You are a medical/skincare assistant. Analyze this image of a pill or medicine.

${userSkinProfile != null && userSkinProfile.isNotEmpty ? "User skin profile (use for safety): $userSkinProfile" : ""}

Respond in this exact JSON structure (no markdown, no extra text). Use plain English, no medical jargon.
{
  "name": "Product or pill name",
  "dosage": "e.g. 500mg",
  "whatIsIt": "Simple description",
  "topUses": "Use 1; Use 2",
  "sideEffects": "Plain English side effects",
  "safetyAlert": "Safety Red Flags",
  "conditionMatch": "Safe for your profile OR Caution",
  "skinImpact": "Yes or No",
  "skinImpactReason": "Brief reason",
  "aiReasoning": "How the active ingredients interact with the body.",
  "callToAction": "Add to routine instructions",
  "confidence": "high|medium|low",
  "detectedType": "pill",
  "recommendations": [
    {
      "productName": "Companion product name (NOT the pill/medicine identified above, MAX 3 suggestions)",
      "whatItDoes": "What it does for health/skin",
      "whyItsGood": "Benefit of using with main medicine",
      "howToUse": "Amount and frequency",
      "ingredients": "Key ingredients + why each helps"
    }
  ]
}
''';

    final contents = [
      {
        'role': 'user',
        'parts': [
          {
            'inlineData': {
              'data': base64Encode(imageBytes),
              'mimeType': 'image/jpeg',
            },
          },
          {
            'text': prompt,
          },
        ],
      },
    ];

    final responseJson =
        await _generateContentWithFallback(contents: contents);
    final text = _extractText(responseJson) ?? '{}';
    return ScanAnalysis.fromGeminiResponse(text, ScanMode.pill);
  }

  /// Analyze skin from image bytes.
  ///
  /// Same fallback behavior as [analyzePill].
  Future<ScanAnalysis> analyzeSkin(
      Uint8List imageBytes, String? userSkinProfile) async {
    final prompt = '''
You are a skincare AI. Analyze this skin image.

${userSkinProfile != null && userSkinProfile.isNotEmpty ? "User skin profile: $userSkinProfile" : ""}

Respond in this exact JSON structure (no markdown, no extra text).
{
  "name": "Acne, dryness, etc.",
  "whatIsIt": "State of skin",
  "theCause": "Biological vs Environmental",
  "allergyWatch": "Ingredients to avoid",
  "dailyRoutine": "Step-by-step routine",
  "safetyAlert": "Allergy Watch",
  "aiReasoning": "Scientific reasoning for condition.",
  "callToAction": "Specific suggestion",
  "confidence": "high|medium|low",
  "skinScore": "integer 0-100",
  "skinStatus": "Brief status (e.g. Glowing, Needs Care, etc.)",
  "detectedType": "skin",
  "recommendations": [
    {
      "productName": "Specific skincare product (e.g. Sunscreen, Moisturizer, MAX 3 suggestions)",
      "whatItDoes": "Action on skin",
      "whyItsGood": "How it addresses the condition",
      "howToUse": "Application guide",
      "ingredients": "Main ingredients + purpose"
    }
  ]
}
''';

    final contents = [
      {
        'role': 'user',
        'parts': [
          {
            'inlineData': {
              'data': base64Encode(imageBytes),
              'mimeType': 'image/jpeg',
            },
          },
          {
            'text': prompt,
          },
        ],
      },
    ];

    final responseJson =
        await _generateContentWithFallback(contents: contents);
    final text = _extractText(responseJson) ?? '{}';
    return ScanAnalysis.fromGeminiResponse(text, ScanMode.skin);
  }

  /// Analyze food for skin/diet triggers.
  ///
  /// Same fallback behavior as [analyzePill].
  Future<ScanAnalysis> analyzeFood(
      Uint8List imageBytes, String? userSkinProfile) async {
    final prompt = '''
You are a diet-skin assistant. Analyze this food image for skin/diet relevance.

${userSkinProfile != null && userSkinProfile.isNotEmpty ? "User profile: $userSkinProfile" : ""}

Respond in this exact JSON structure (no markdown, no extra text).
{
  "name": "Food name",
  "whatIsIt": "Nutrient profile",
  "skinImpactRating": "green|yellow|red",
  "acneTriggers": "IGF-1 or Glycation relevance",
  "healthAlerts": "Blood sugar/allergies",
  "betterSwap": "Alternative food",
  "portionGuide": "Precise limit",
  "safetyAlert": "Acne/health triggers",
  "aiReasoning": "How compounds affect skin/sebum.",
  "callToAction": "Portion/Swap guidance",
  "confidence": "high|medium|low",
  "detectedType": "food",
  "recommendations": [
    {
      "productName": "Companion side dish, supplement, or beverage (NOT the food identified above, MAX 3 suggestions)",
      "whatItDoes": "Action on health/skin",
      "whyItsGood": "Benefit of using with this food",
      "howToUse": "Portion guide",
      "ingredients": "Ingredients + why they help"
    }
  ]
}
''';

    final contents = [
      {
        'role': 'user',
        'parts': [
          {
            'inlineData': {
              'data': base64Encode(imageBytes),
              'mimeType': 'image/jpeg',
            },
          },
          {
            'text': prompt,
          },
        ],
      },
    ];

    final responseJson =
        await _generateContentWithFallback(contents: contents);
    final text = _extractText(responseJson) ?? '{}';
    return ScanAnalysis.fromGeminiResponse(text, ScanMode.food);
  }

  /// Compare two skin images side-by-side for progress analysis.
  Future<String> compareSkinSideBySide(Uint8List imageOld, Uint8List imageNew) async {
    final prompt = '''
You are a skin health expert. Analyze these two skin images.
The image on the left is the OLDER one, and the image on the right is the MORE RECENT one.
Assess the skin health progress between these two images.
Compare them and summarize the changes in 2-3 concise sentences.
Determine whether the skin health is improving or worsening overall.
Respond in a concise, expert tone but do NOT use the phrase "skin health expert" or "doctor" in your response.
''';
    try {
      final contents = [
        {
          'role': 'user',
          'parts': [
            {'text': prompt},
            {
              'inlineData': {
                'data': base64Encode(imageOld),
                'mimeType': 'image/jpeg',
              },
            },
            {
              'inlineData': {
                'data': base64Encode(imageNew),
                'mimeType': 'image/jpeg',
              },
            },
          ],
        },
      ];

      final responseJson =
          await _generateContentWithFallback(contents: contents);
      final text = _extractText(responseJson);
      return text ?? 'Could not generate comparison.';
    } catch (e) {
      return 'Comparison error: $e';
    }
  }

  /// AI Insight of the Day (dashboard).
  Future<String> getInsightOfTheDay(int skinScore, String? recentActivity) async {
    final prompt = '''
You are Foryou AI. In one short, friendly sentence, give a personalized skin insight.
User's daily skin score: $skinScore%. ${recentActivity != null ? "Recent: $recentActivity" : ""}
Reply with only that one sentence, no quotes.
''';
    final contents = [
      {
        'role': 'user',
        'parts': [
          {'text': prompt},
        ],
      },
    ];

    final responseJson =
        await _generateContentWithFallback(contents: contents);
    final text = _extractText(responseJson);
    return text?.trim() ?? 'Your skin is looking great today!';
  }

  /// Agentic scheduling: when to remind user to reapply (e.g. medication).
  /// Input: appliedAt "8 AM", durationHours 6, nextEvent "meeting at 2 PM".
  Future<String> getBestReminderTime({
    required String appliedAt,
    required int durationHours,
    String? nextEvent,
  }) async {
    final prompt = '''
The user applied their medication at $appliedAt. It lasts for $durationHours hours.
${nextEvent != null ? "They have: $nextEvent." : ""}
When is the best time to remind them to reapply? Reply with one short sentence (e.g. "Remind at 2 PM, 30 minutes before your meeting.").
''';
    final contents = [
      {
        'role': 'user',
        'parts': [
          {'text': prompt},
        ],
      },
    ];

    final responseJson =
        await _generateContentWithFallback(contents: contents);
    final text = _extractText(responseJson);
    return text?.trim() ?? 'Remind in $durationHours hours.';
  }
  /// Chat with the AI coach.
  Future<String> coachChat(List<MapEntry<String, String>> history, String userMessage) async {
    final contents = <Map<String, dynamic>>[];
    for (final entry in history) {
      if (entry.key.isNotEmpty) {
        contents.add({
          'role': 'user',
          'parts': [
            {'text': entry.key},
          ],
        });
      }
      if (entry.value.isNotEmpty) {
        contents.add({
          'role': 'model',
          'parts': [
            {'text': entry.value},
          ],
        });
      }
    }
    contents.add({
      'role': 'user',
      'parts': [
        {'text': userMessage},
      ],
    });

    const systemInstruction =
        "You are a health expert, dermatologist, and skin health expert. "
        "Your mindset is to provide professional, accurate, and encouraging skincare and health advice. "
        "Never explicitly state that you are a health expert, dermatologist, or skin health expert in your responses. "
        "Stay in character and answer from this professional perspective.";

    final responseJson = await _generateContentWithFallback(
      contents: contents,
      systemInstruction: systemInstruction,
    );
    final text = _extractText(responseJson);
    return text?.trim() ??
        "I'm here to help. Try asking about your routine or progress.";
  }

  /// Compare before/after skin (for Context Caching: cache Day 1 image and
  /// send Day 2 with reference to cache for faster, cheaper comparison).
  Future<String> compareSkinProgress(Uint8List beforeImage, Uint8List afterImage) async {
    final prompt = '''
Compare these two skin images (before and after). Describe improvements in 2-3 short sentences (e.g. reduced redness, clearer texture). Be specific and encouraging.
''';
    final contents = [
      {
        'role': 'user',
        'parts': [
          {
            'inlineData': {
              'data': base64Encode(beforeImage),
              'mimeType': 'image/jpeg',
            },
          },
          {'text': '--- BEFORE ---'},
          {
            'inlineData': {
              'data': base64Encode(afterImage),
              'mimeType': 'image/jpeg',
            },
          },
          {'text': '--- AFTER ---\n$prompt'},
        ],
      },
    ];

    final responseJson =
        await _generateContentWithFallback(contents: contents);
    final text = _extractText(responseJson);
    return text?.trim() ??
        'Comparison complete. Keep up your routine!';
  }

  /// Core HTTP call with model selection.
  Future<Map<String, dynamic>> _generateContent({
    required String model,
    required List<Map<String, dynamic>> contents,
    String? systemInstruction,
  }) async {
    if (GeminiConfig.apiKey.isEmpty) {
      throw Exception(
          'GEMINI_API_KEY is not set. Provide it via --dart-define=GEMINI_API_KEY=...');
    }

    final uri = Uri.parse(
        '$_apiBase/models/$model:generateContent?key=${GeminiConfig.apiKey}');

    final body = <String, dynamic>{
      'contents': contents,
    };

    if (systemInstruction != null && systemInstruction.isNotEmpty) {
      body['systemInstruction'] = {
        'role': 'user',
        'parts': [
          {'text': systemInstruction},
        ],
      };
    }

    debugPrint('🔮 Calling Gemini model: $model');
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    final decoded =
        response.body.isNotEmpty ? jsonDecode(response.body) : null;

    if (response.statusCode == 200 && decoded is Map<String, dynamic>) {
      return decoded;
    }

    final error = decoded is Map<String, dynamic> ? decoded['error'] : null;
    final errorMessage =
        error is Map<String, dynamic> ? (error['message'] as String?) : null;
    final errorCode =
        error is Map<String, dynamic> ? (error['status'] as String?) : null;

    throw GeminiApiException(
      statusCode: response.statusCode,
      code: errorCode,
      message: errorMessage ??
          'Gemini API error (HTTP ${response.statusCode}): ${response.body}',
    );
  }

  /// Try models in order until one succeeds, handling rate limits gracefully.
  Future<Map<String, dynamic>> _generateContentWithFallback({
    required List<Map<String, dynamic>> contents,
    String? systemInstruction,
  }) async {
    final models = [primaryModel, fallbackModel1, fallbackModel2];

    GeminiApiException? lastRateLimit;
    Exception? lastOther;

    for (final model in models) {
      try {
        final json = await _generateContent(
          model: model,
          contents: contents,
          systemInstruction: systemInstruction,
        );
        debugPrint('✅ Gemini call succeeded with model: $model');
        return json;
      } on GeminiApiException catch (e) {
        debugPrint('⚠️  Gemini model $model failed: ${e.message}');

        final isRateLimited = e.statusCode == 429 ||
            e.code == 'RESOURCE_EXHAUSTED' ||
            e.code == 'RATE_LIMIT_EXCEEDED';

        if (isRateLimited) {
          lastRateLimit = e;
          debugPrint(
              '🔁 Model $model is rate-limited or quota-exhausted. Falling back to next model.');
          continue;
        }

        lastOther = e;
        debugPrint('🔁 Non-rate-limit error for $model. Trying next model...');
        continue;
      } catch (e) {
        lastOther = e is Exception ? e : Exception(e.toString());
        debugPrint('⚠️  Unexpected error for $model: $e');
        continue;
      }
    }

    // If all models failed, surface the most informative error.
    if (lastOther != null) throw lastOther;
    if (lastRateLimit != null) throw lastRateLimit;
    throw Exception('All Gemini models failed with unknown errors.');
  }

  /// Extract plain text from a Gemini generateContent response.
  String? _extractText(Map<String, dynamic> json) {
    final candidates = json['candidates'];
    if (candidates is List && candidates.isNotEmpty) {
      final content = candidates.first['content'];
      if (content is Map<String, dynamic>) {
        final parts = content['parts'];
        if (parts is List && parts.isNotEmpty) {
          final buffer = StringBuffer();
          for (final part in parts) {
            if (part is Map<String, dynamic>) {
              final text = part['text'];
              if (text is String && text.isNotEmpty) {
                buffer.write(text);
              }
            }
          }
          final result = buffer.toString();
          return result.isEmpty ? null : result;
        }
      }
    }
    return null;
  }
}

/// Structured Gemini API exception with HTTP status and error code.
class GeminiApiException implements Exception {
  GeminiApiException({
    required this.statusCode,
    this.code,
    required this.message,
  });

  final int statusCode;
  final String? code;
  final String message;

  @override
  String toString() => 'GeminiApiException($statusCode, $code, $message)';
}

enum ScanMode { pill, skin, food }

class Recommendation {
  final String productName;
  final String whatItDoes;
  final String whyItsGood;
  final String howToUse;
  final String ingredients;

  Recommendation({
    required this.productName,
    required this.whatItDoes,
    required this.whyItsGood,
    required this.howToUse,
    required this.ingredients,
  });

  Map<String, dynamic> toJson() => {
    'productName': productName,
    'whatItDoes': whatItDoes,
    'whyItsGood': whyItsGood,
    'howToUse': howToUse,
    'ingredients': ingredients,
  };

  factory Recommendation.fromJson(Map<String, dynamic> json) => Recommendation(
    productName: json['productName'] ?? '',
    whatItDoes: json['whatItDoes'] ?? '',
    whyItsGood: json['whyItsGood'] ?? '',
    howToUse: json['howToUse'] ?? '',
    ingredients: json['ingredients'] ?? '',
  );
}

class ScanAnalysis {
  ScanAnalysis({
    required this.mode,
    required this.name,
    required this.dosage,
    required this.whatIsIt,
    required this.safetyAlert,
    required this.aiReasoning,
    this.confidence = 'medium',
    this.rawResponse,
    this.topUses,
    this.sideEffects,
    this.conditionMatch,
    this.skinImpact,
    this.skinImpactReason,
    this.theCause,
    this.allergyWatch,
    this.dailyRoutine,
    this.whenToSeePro,
    this.skinImpactRating,
    this.acneTriggers,
    this.healthAlerts,
    this.betterSwap,
    this.portionGuide,
    this.callToAction,
    this.skinScore,
    this.skinStatus,
    this.recommendations = const [],
  });

  final ScanMode mode;
  final String name;
  final String dosage;
  final String whatIsIt;
  final String safetyAlert;
  final String aiReasoning;
  final String confidence;
  final String? rawResponse;
  // Pill
  final String? topUses;
  final String? sideEffects;
  final String? conditionMatch;
  final String? skinImpact;
  final String? skinImpactReason;
  // Skin
  final String? theCause;
  final String? allergyWatch;
  final String? dailyRoutine;
  final String? whenToSeePro;
  // Food
  final String? skinImpactRating;
  final String? acneTriggers;
  final String? healthAlerts;
  final String? betterSwap;
  final String? portionGuide;
  final String? callToAction;
  final int? skinScore;
  final String? skinStatus;
  final List<Recommendation> recommendations;

  String get effectiveCallToAction =>
      callToAction?.isNotEmpty == true
          ? callToAction!
          : 'Add to routine: $name';

  Map<String, dynamic> toJson() => {
    'mode': mode.name,
    'name': name,
    'dosage': dosage,
    'whatIsIt': whatIsIt,
    'safetyAlert': safetyAlert,
    'aiReasoning': aiReasoning,
    'confidence': confidence,
    'rawResponse': rawResponse,
    'topUses': topUses,
    'sideEffects': sideEffects,
    'conditionMatch': conditionMatch,
    'skinImpact': skinImpact,
    'skinImpactReason': skinImpactReason,
    'theCause': theCause,
    'allergyWatch': allergyWatch,
    'dailyRoutine': dailyRoutine,
    'whenToSeePro': whenToSeePro,
    'skinImpactRating': skinImpactRating,
    'acneTriggers': acneTriggers,
    'healthAlerts': healthAlerts,
    'betterSwap': betterSwap,
    'portionGuide': portionGuide,
    'callToAction': callToAction,
    'skinScore': skinScore,
    'skinStatus': skinStatus,
    'recommendations': recommendations.map((e) => e.toJson()).toList(),
  };

  factory ScanAnalysis.fromJson(Map<String, dynamic> json) {
    return ScanAnalysis(
      mode: ScanMode.values.firstWhere((e) => e.name == json['mode'], orElse: () => ScanMode.pill),
      name: json['name'] ?? '',
      dosage: json['dosage'] ?? '',
      whatIsIt: json['whatIsIt'] ?? '',
      safetyAlert: json['safetyAlert'] ?? '',
      aiReasoning: json['aiReasoning'] ?? '',
      confidence: json['confidence'] ?? 'medium',
      rawResponse: json['rawResponse'],
      topUses: json['topUses'],
      sideEffects: json['sideEffects'],
      conditionMatch: json['conditionMatch'],
      skinImpact: json['skinImpact'],
      skinImpactReason: json['skinImpactReason'],
      theCause: json['theCause'],
      allergyWatch: json['allergyWatch'],
      dailyRoutine: json['dailyRoutine'],
      whenToSeePro: json['whenToSeePro'],
      skinImpactRating: json['skinImpactRating'],
      acneTriggers: json['acneTriggers'],
      healthAlerts: json['healthAlerts'],
      betterSwap: json['betterSwap'],
      portionGuide: json['portionGuide'],
      callToAction: json['callToAction'],
      skinScore: json['skinScore'],
      skinStatus: json['skinStatus'],
      recommendations: (json['recommendations'] as List?)
          ?.map((e) => Recommendation.fromJson(e as Map<String, dynamic>))
          .toList() ?? const [],
    );
  }

  factory ScanAnalysis.fromGeminiResponse(String raw, ScanMode mode) {
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      
      // Dynamic mode switching
      ScanMode effectiveMode = mode;
      final type = (json['detectedType'] as String?)?.toLowerCase() ?? '';
      if (type.contains('pill')) {
        effectiveMode = ScanMode.pill;
      } else if (type.contains('skin')) {
        effectiveMode = ScanMode.skin;
      } else if (type.contains('food')) {
        effectiveMode = ScanMode.food;
      }

      return ScanAnalysis(
        mode: effectiveMode,
        name: json['name'] ?? 'Unknown',
        dosage: json['dosage'] ?? '',
        whatIsIt: json['whatIsIt'] ?? '',
        safetyAlert: json['safetyAlert'] ?? 'None identified',
        aiReasoning: json['aiReasoning'] ?? '',
        confidence: json['confidence'] ?? 'medium',
        rawResponse: raw,
        topUses: json['topUses'],
        sideEffects: json['sideEffects'],
        conditionMatch: json['conditionMatch'],
        skinImpact: json['skinImpact'],
        skinImpactReason: json['skinImpactReason'],
        theCause: json['theCause'],
        allergyWatch: json['allergyWatch'],
        dailyRoutine: json['dailyRoutine'],
        whenToSeePro: json['whenToSeePro'],
        skinImpactRating: json['skinImpactRating'],
        acneTriggers: json['acneTriggers'],
        healthAlerts: json['healthAlerts'],
        betterSwap: json['betterSwap'],
        portionGuide: json['portionGuide'],
        callToAction: json['callToAction'],
        skinScore: json['skinScore'] is int ? json['skinScore'] : int.tryParse(json['skinScore']?.toString() ?? ''),
        skinStatus: json['skinStatus'],
        recommendations: (json['recommendations'] as List?)
            ?.map((e) => Recommendation.fromJson(e as Map<String, dynamic>))
            .toList() ?? const [],
      );
    } catch (e) {
      debugPrint('Error parsing Gemini response: $e');
      return ScanAnalysis(
        mode: mode,
        name: 'Parsing Error',
        dosage: '',
        whatIsIt: 'Could not parse AI response.',
        safetyAlert: 'Raw output: $raw',
        aiReasoning: 'Error: $e',
        rawResponse: raw,
      );
    }
  }
}
