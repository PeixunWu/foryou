import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'admob_config.dart';
import 'tracking_consent_service.dart';

/// Production interstitial ads with full-screen lifecycle callbacks.
class InterstitialAdManager {
  InterstitialAdManager._();
  static final InterstitialAdManager instance = InterstitialAdManager._();

  InterstitialAd? _interstitialAd;
  bool _isLoading = false;

  bool get isAdReady => _interstitialAd != null;

  Future<void> loadAd() async {
    if (_isLoading || _interstitialAd != null) return;
    _isLoading = true;

    final request = await TrackingConsentService.buildAdRequest();

    await InterstitialAd.load(
      adUnitId: AdMobConfig.interstitialAdUnitId,
      request: request,
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _isLoading = false;
          _interstitialAd = ad;
          _registerCallbacks(ad);
          if (kDebugMode) debugPrint('Interstitial ad loaded.');
        },
        onAdFailedToLoad: (error) {
          _isLoading = false;
          if (kDebugMode) {
            debugPrint('Interstitial ad failed to load: ${error.message}');
          }
        },
      ),
    );
  }

  void _registerCallbacks(InterstitialAd ad) {
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        if (kDebugMode) debugPrint('Interstitial ad showed.');
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        if (kDebugMode) {
          debugPrint('Interstitial failed to show: ${error.message}');
        }
        ad.dispose();
        _interstitialAd = null;
        loadAd();
      },
      onAdDismissedFullScreenContent: (ad) {
        if (kDebugMode) debugPrint('Interstitial ad dismissed.');
        ad.dispose();
        _interstitialAd = null;
        loadAd();
      },
    );
  }

  Future<void> showIfAvailable() async {
    final ad = _interstitialAd;
    if (ad == null) {
      await loadAd();
      return;
    }
    await ad.show();
  }

  void dispose() {
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isLoading = false;
  }
}
