import 'package:flutter/material.dart';

import '../config/ai_config.dart';

class ApiKeyDebugScreen extends StatelessWidget {
  const ApiKeyDebugScreen({super.key});

  String _preview(String key) {
    if (key.isEmpty) return 'Not set';
    if (key.length <= 10) return '${key.substring(0, key.length)}...';
    return '${key.substring(0, 10)}...';
  }

  @override
  Widget build(BuildContext context) {
    final providers = [
      ('GEMINI_API_KEY (Primary Gemini 3)', AiConfig.geminiApiKey),
      ('GEMINI_OLD_KEY (Fallback 1.5 Flash)', AiConfig.geminiOldKey),
      ('GROQ_API_KEY (Fallback Groq)', AiConfig.groqApiKey),
      ('OPENROUTER_API_KEY (Fallback OpenRouter)', AiConfig.openRouterApiKey),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('API Key Debug')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            Text(
              'AI provider keys (compile-time)',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'Keys are loaded via --dart-define at build/run time. Never commit secrets to source control.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 20),
            ...providers.map((p) {
              final isSet = p.$2.isNotEmpty;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isSet ? Icons.check_circle : Icons.error_outline,
                            color: isSet ? Colors.green : Colors.orange,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              p.$1,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Preview: ${_preview(p.$2)}'),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
            const Text(
              'Example:\n'
              'flutter run \\\n'
              '  --dart-define=GEMINI_API_KEY=... \\\n'
              '  --dart-define=GEMINI_OLD_KEY=... \\\n'
              '  --dart-define=GROQ_API_KEY=... \\\n'
              '  --dart-define=OPENROUTER_API_KEY=...',
              style: TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
