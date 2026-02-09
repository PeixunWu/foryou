# Foryou AI - Setup Guide

## Quick Start

### 1. Get Your API Key
Generate a Gemini API key from [Google AI Studio](https://aistudio.google.com/).

### 2. Run the App

**The simplest way to run on iOS or Android:**

```bash
flutter run --release --dart-define=GEMINI_API_KEY=your_actual_api_key_here
```

Replace `your_actual_api_key_here` with your actual Gemini API key.

> **Important**: Always use the `--dart-define` flag - never hardcode your API key in the source code.

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
flutter build appbundle --release --dart-define=GEMINI_API_KEY=your_actual_api_key_here
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
