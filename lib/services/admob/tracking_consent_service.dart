import 'dart:io';

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// ATT + non-personalized ads (NPA) when the user denies tracking on iOS.
class TrackingConsentService {
  TrackingConsentService._();

  static bool? _testOverrideUseNpa;

  /// Test-only: force NPA on/off without calling ATT APIs.
  @visibleForTesting
  static void setTestOverrideUseNpa(bool? useNpa) {
    _testOverrideUseNpa = useNpa;
  }

  @visibleForTesting
  static void resetForTest() {
    _testOverrideUseNpa = null;
    _lastKnownStatus = null;
  }

  static TrackingStatus? _lastKnownStatus;

  static TrackingStatus? get lastKnownStatus => _lastKnownStatus;

  /// Whether ads must be non-personalized (no IDFA).
  static Future<bool> shouldUseNonPersonalizedAds() async {
    if (_testOverrideUseNpa != null) return _testOverrideUseNpa!;
    if (!Platform.isIOS) return false;

    final status = _lastKnownStatus ??
        await AppTrackingTransparency.trackingAuthorizationStatus;
    _lastKnownStatus = status;

    switch (status) {
      case TrackingStatus.authorized:
        return false;
      case TrackingStatus.denied:
      case TrackingStatus.restricted:
      case TrackingStatus.notSupported:
        return true;
      case TrackingStatus.notDetermined:
        return false;
    }
  }

  /// Builds an [AdRequest] with NPA when tracking is denied on iOS.
  static Future<AdRequest> buildAdRequest() async {
    final npa = await shouldUseNonPersonalizedAds();
    if (kDebugMode) {
      debugPrint(
        'AdMob AdRequest: nonPersonalizedAds=$npa (ATT=${_lastKnownStatus?.name ?? "unknown"})',
      );
    }
    return AdRequest(nonPersonalizedAds: npa);
  }

  @visibleForTesting
  static AdRequest buildAdRequestForTest({required bool nonPersonalizedAds}) {
    return AdRequest(nonPersonalizedAds: nonPersonalizedAds);
  }

  /// Request ATT on first launch. Call after the first frame (required for iPad).
  static Future<TrackingStatus?> requestOnLaunch() async {
    if (!Platform.isIOS) return null;

    try {
      // Let the window become key (fixes missing prompt on some iPadOS builds).
      await Future<void>.delayed(const Duration(milliseconds: 500));

      var status = await AppTrackingTransparency.trackingAuthorizationStatus;
      _lastKnownStatus = status;

      if (status == TrackingStatus.notDetermined) {
        status = await AppTrackingTransparency.requestTrackingAuthorization();
        _lastKnownStatus = status;
      }

      if (kDebugMode) {
        debugPrint('ATT status after request: ${status.name}');
      }
      return status;
    } catch (e, st) {
      debugPrint('ATT request failed: $e');
      if (kDebugMode) debugPrint('$st');
      return _lastKnownStatus;
    }
  }
}
