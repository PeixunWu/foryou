import 'dart:convert';

class CoachMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  CoachMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'isUser': isUser,
        'timestamp': timestamp.toIso8601String(),
      };

  factory CoachMessage.fromJson(Map<String, dynamic> json) => CoachMessage(
        text: json['text'] as String,
        isUser: json['isUser'] as bool,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}
