import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'admob_config.dart';
import 'tracking_consent_service.dart';

/// Loads and shows production app open ads; one ad per foreground event.
class AppOpenAdManager {
  AppOpenAdManager._();
  static final AppOpenAdManager instance = AppOpenAdManager._();

  AppOpenAd? _appOpenAd;
  DateTime? _loadTime;
  bool _isLoading = false;
  bool _isShowing = false;
  bool _pendingShowOnLoad = false;

  bool get isShowingAd => _isShowing;

  bool get _isAdFresh {
    if (_loadTime == null) return false;
    return DateTime.now().difference(_loadTime!) < AdMobConfig.appOpenMaxCacheAge;
  }

  bool get isAdAvailable => _appOpenAd != null && _isAdFresh;

  /// Called when the app enters foreground (cold start or resume).
  Future<void> onAppForeground() async {
    if (_isShowing) return;
    if (isAdAvailable) {
      await _showCachedAd();
      return;
    }
    await _loadAd(showImmediatelyWhenLoaded: true);
  }

  Future<void> _loadAd({required bool showImmediatelyWhenLoaded}) async {
    if (_isLoading) {
      if (showImmediatelyWhenLoaded) _pendingShowOnLoad = true;
      return;
    }
    if (isAdAvailable) {
      if (showImmediatelyWhenLoaded) await _showCachedAd();
      return;
    }

    _isLoading = true;
    _pendingShowOnLoad = showImmediatelyWhenLoaded;
    _disposeAd();

    final request = await TrackingConsentService.buildAdRequest();

    await AppOpenAd.load(
      adUnitId: AdMobConfig.appOpenAdUnitId,
      request: request,
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _isLoading = false;
          _appOpenAd = ad;
          _loadTime = DateTime.now();
          _registerFullScreenCallbacks(ad);
          if (kDebugMode) debugPrint('App open ad loaded.');
          if (_pendingShowOnLoad) {
            _pendingShowOnLoad = false;
            _showCachedAd();
          }
        },
        onAdFailedToLoad: (error) {
          _isLoading = false;
          _pendingShowOnLoad = false;
          if (kDebugMode) {
            debugPrint('App open ad failed to load: ${error.message}');
          }
        },
      ),
    );
  }

  void _registerFullScreenCallbacks(AppOpenAd ad) {
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        _isShowing = true;
        if (kDebugMode) debugPrint('App open ad showed.');
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        if (kDebugMode) {
          debugPrint('App open ad failed to show: ${error.message}');
        }
        _isShowing = false;
        ad.dispose();
        _appOpenAd = null;
        _loadTime = null;
      },
      onAdDismissedFullScreenContent: (ad) {
        if (kDebugMode) debugPrint('App open ad dismissed.');
        _isShowing = false;
        ad.dispose();
        _appOpenAd = null;
        _loadTime = null;
      },
    );
  }

  Future<void> _showCachedAd() async {
    final ad = _appOpenAd;
    if (ad == null || !_isAdFresh || _isShowing) return;
    _registerFullScreenCallbacks(ad);
    await ad.show();
  }

  void _disposeAd() {
    _appOpenAd?.dispose();
    _appOpenAd = null;
    _loadTime = null;
  }

  void dispose() {
    _disposeAd();
    _isLoading = false;
    _isShowing = false;
    _pendingShowOnLoad = false;
  }
}
