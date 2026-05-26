import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'ai_fallback_manager.dart';

/// App-facing AI service. All requests go through [AiFallbackManager]:
/// Gemini 3 → Gemini 1.5 (legacy key) → Groq → OpenRouter.
class GeminiService {
  GeminiService({http.Client? client})
      : _fallback = AiFallbackManager(client: client);

  final AiFallbackManager _fallback;

  static const String primaryModel = AiFallbackManager.gemini3Model;
  static const String fallbackModel1 = AiFallbackManager.gemini15Model;

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

    final text = await _fallback.complete(
      AiRequest(
        prompt: prompt,
        images: [AiImagePart(imageBytes)],
      ),
      fallbackMessage: '{}',
    );
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

    final text = await _fallback.complete(
      AiRequest(
        prompt: prompt,
        images: [AiImagePart(imageBytes)],
      ),
      fallbackMessage: '{}',
    );
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

    final text = await _fallback.complete(
      AiRequest(
        prompt: prompt,
        images: [AiImagePart(imageBytes)],
      ),
      fallbackMessage: '{}',
    );
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
    return _fallback.complete(
      AiRequest(
        prompt: prompt,
        images: [
          AiImagePart(imageOld),
          AiImagePart(imageNew),
        ],
      ),
      fallbackMessage: 'Could not generate comparison. Please try again.',
    );
  }

  /// AI Insight of the Day (dashboard).
  Future<String> getInsightOfTheDay(int skinScore, String? recentActivity) async {
    final prompt = '''
You are Foryou AI. In one short, friendly sentence, give a personalized skin insight.
User's daily skin score: $skinScore%. ${recentActivity != null ? "Recent: $recentActivity" : ""}
Reply with only that one sentence, no quotes.
''';
    final text = await _fallback.complete(
      AiRequest(prompt: prompt),
      fallbackMessage: 'Your skin is looking great today!',
    );
    return text.trim();
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
    final text = await _fallback.complete(
      AiRequest(prompt: prompt),
      fallbackMessage: 'Remind in $durationHours hours.',
    );
    return text.trim();
  }
  /// Chat with the AI coach.
  Future<String> coachChat(List<MapEntry<String, String>> history, String userMessage) async {
    final chatHistory = <AiChatTurn>[];
    for (final entry in history) {
      if (entry.key.isNotEmpty) {
        chatHistory.add(AiChatTurn(role: 'user', text: entry.key));
      }
      if (entry.value.isNotEmpty) {
        chatHistory.add(AiChatTurn(role: 'assistant', text: entry.value));
      }
    }

    const systemInstruction =
        "You are a health expert, dermatologist, and skin health expert. "
        "Your mindset is to provide professional, accurate, and encouraging skincare and health advice. "
        "Never explicitly state that you are a health expert, dermatologist, or skin health expert in your responses. "
        "Stay in character and answer from this professional perspective.";

    final text = await _fallback.complete(
      AiRequest(
        prompt: userMessage,
        systemInstruction: systemInstruction,
        chatHistory: chatHistory,
      ),
      fallbackMessage:
          "I'm here to help. Try asking about your routine or progress.",
    );
    return text.trim();
  }

  /// Compare before/after skin (for Context Caching: cache Day 1 image and
  /// send Day 2 with reference to cache for faster, cheaper comparison).
  Future<String> compareSkinProgress(Uint8List beforeImage, Uint8List afterImage) async {
    final prompt = '''
Compare these two skin images (before and after). Describe improvements in 2-3 short sentences (e.g. reduced redness, clearer texture). Be specific and encouraging.
''';
    final text = await _fallback.complete(
      AiRequest(
        prompt: '--- BEFORE ---\n--- AFTER ---\n$prompt',
        images: [
          AiImagePart(beforeImage),
          AiImagePart(afterImage),
        ],
      ),
      fallbackMessage: 'Comparison complete. Keep up your routine!',
    );
    return text.trim();
  }
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
