# Foryou AI - Setup Guide

## Quick Start

### 1. Get Your API Keys

- **Primary**: Gemini API key from [Google AI Studio](https://aistudio.google.com/) (`GEMINI_API_KEY`)
- **Fallback 1** (optional): Second Google key for Gemini 1.5 Flash (`GEMINI_OLD_KEY`)
- **Fallback 2** (optional): [Groq](https://console.groq.com/) API key (`GROQ_API_KEY`)
- **Fallback 3** (optional): [OpenRouter](https://openrouter.ai/) API key (`OPENROUTER_API_KEY`)

The app tries providers in order: **Gemini 3 → Gemini 1.5 (old key) → Groq → OpenRouter**, so scans and chat keep working when one provider is rate-limited.

### 2. Run the App

**The simplest way to run on iOS or Android:**

```bash
flutter run --release \
  --dart-define=GEMINI_API_KEY=your_gemini_key \
  --dart-define=GEMINI_OLD_KEY=your_legacy_gemini_key \
  --dart-define=GROQ_API_KEY=your_groq_key \
  --dart-define=OPENROUTER_API_KEY=your_openrouter_key
```

Only `GEMINI_API_KEY` is required for basic use; add the others for full fallback coverage.

> **Important**: Always use `--dart-define` — never hardcode API keys in source code.

### 3. Build for Production

**iOS (App Store):**
```bash
flutter build ios --release --dart-define=GEMINI_API_KEY=your_actual_api_key_here
```
Then open `ios/Runner.xcworkspace` in Xcode and select Product > Archive.

**Android APK:**
```bash
flutter build apk --release --dart-define=GEMINI_API_KEY=your_actual_api_key_here
```

**Android App Bundle (Google Play):**
```bash
flutter build appbundle --release \
  --dart-define=GEMINI_API_KEY=your_gemini_key \
  --dart-define=GEMINI_OLD_KEY=your_legacy_gemini_key \
  --dart-define=GROQ_API_KEY=your_groq_key \
  --dart-define=OPENROUTER_API_KEY=your_openrouter_key
```

## IDE Configuration (Optional)

### Android Studio
1. Go to Run > Edit Configurations
2. Add to "Additional arguments": `--dart-define=GEMINI_API_KEY=your_actual_api_key_here`
3. Click Apply

### VS Code
Create/edit `.vscode/launch.json`:
```json
{
  "configurations": [
    {
      "name": "foryou",
      "request": "launch",
      "type": "dart",
      "args": ["--dart-define", "GEMINI_API_KEY=your_actual_api_key_here"]
    }
  ]
}
```

## AdMob (production)

App open ads show on cold start and each time the app returns to the foreground. iOS shows the App Tracking Transparency dialog on first launch (including iPad); if the user taps **Ask App Not to Track**, ads still load as **non-personalized** (NPA).

Rebuild with the same `--dart-define` flags as AI keys are separate.

## Troubleshooting

**Build errors or crashes?**
```bash
flutter clean
flutter pub get
flutter run --release --dart-define=GEMINI_API_KEY=your_actual_api_key_here
```

**AI features not working?**
Make sure you're using the `--dart-define` flag when running or building the app. Check the console for this warning:
```
⚠️ WARNING: GEMINI_API_KEY is not set!
```

**Want to use hot reload during development?**
Use the iOS Simulator or Android Emulator instead of a physical device:
```bash
flutter run --dart-define=GEMINI_API_KEY=your_actual_api_key_here
```
(Without the `--release` flag, hot reload will work on emulators/simulators)
