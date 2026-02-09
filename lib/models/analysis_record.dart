import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../services/gemini_service.dart';

/// Persistent analysis record with image and metadata.
class AnalysisRecord {
  AnalysisRecord({
    required this.id,
    required this.analysis,
    required this.imageBytes,
    required this.createdAt,
    this.imagePath,
  });

  final String id;
  final ScanAnalysis analysis;
  final Uint8List imageBytes;
  final DateTime createdAt;
  final String? imagePath;

  Map<String, dynamic> toJson() => {
        'id': id,
        'mode': analysis.mode.name,
        'rawResponse': analysis.rawResponse ?? '',
        'imagePath': imagePath,
        'createdAt': createdAt.toIso8601String(),
      };

  static Future<AnalysisRecord?> fromJson(Map<String, dynamic> json) async {
    try {
      final id = json['id'] as String? ?? '';
      final modeStr = json['mode'] as String? ?? 'pill';
      final raw = json['rawResponse'] as String? ?? '{}';
      final path = json['imagePath'] as String?;
      final b64 = json['imageBase64'] as String? ?? '';
      final createdAtStr = json['createdAt'] as String? ?? DateTime.now().toIso8601String();

      if (id.isEmpty) return null;

      final mode = ScanMode.values.firstWhere(
        (m) => m.name == modeStr,
        orElse: () => ScanMode.pill,
      );
      final analysis = ScanAnalysis.fromGeminiResponse(raw, mode);

      Uint8List? bytes;
      if (path != null && path.isNotEmpty) {
        try {
          final file = File(path);
          if (await file.exists()) {
            bytes = await file.readAsBytes();
          }
        } catch (_) {}
      }
      
      // Fallback to base64 if file failed or doesn't exist (legacy records)
      if (bytes == null && b64.isNotEmpty) {
        try {
          bytes = base64Decode(b64);
        } catch (_) {}
      }

      if (bytes == null) return null;

      return AnalysisRecord(
        id: id,
        analysis: analysis,
        imageBytes: bytes,
        createdAt: DateTime.tryParse(createdAtStr) ?? DateTime.now(),
        imagePath: path,
      );
    } catch (_) {
      return null;
    }
  }
}
