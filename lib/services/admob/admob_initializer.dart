import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'app_open_ad_manager.dart';

/// Initializes the Mobile Ads SDK and foreground app-open ad listening.
class AdMobInitializer {
  AdMobInitializer._();

  static bool _initialized = false;
  static bool _listening = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    // Production: do not register test device IDs.
    await MobileAds.instance.initialize();
    _initialized = true;

    if (kDebugMode) {
      debugPrint('Google Mobile Ads SDK initialized (production ad units).');
    }
  }

  static void startAppOpenForegroundListener() {
    if (_listening) return;
    _listening = true;
    AppStateEventNotifier.startListening();
    AppStateEventNotifier.appStateStream.listen((state) {
      if (state == AppState.foreground) {
        AppOpenAdManager.instance.onAppForeground();
      }
    });
    if (kDebugMode) {
      debugPrint('App open ad foreground listener started.');
    }
  }

  @visibleForTesting
  static void resetForTest() {
    _initialized = false;
    _listening = false;
  }
}
