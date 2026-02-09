import 'package:flutter/material.dart';
import '../config/gemini_config.dart';

class ApiKeyDebugScreen extends StatelessWidget {
  const ApiKeyDebugScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final apiKey = GeminiConfig.apiKey;
    final isSet = apiKey.isNotEmpty;
    final preview = isSet ? '${apiKey.substring(0, 10)}...' : 'Not set';

    return Scaffold(
      appBar: AppBar(title: const Text('API Key Debug')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'API Key Status',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isSet ? Icons.check_circle : Icons.error,
                          color: isSet ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isSet ? 'API Key is configured' : 'API Key is MISSING',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSet ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('Preview: $preview'),
                    if (!isSet) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Run with:\nflutter run --release --dart-define=GEMINI_API_KEY=your_key',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
