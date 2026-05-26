import 'package:flutter_test/flutter_test.dart';
import 'package:foryou/services/admob/tracking_consent_service.dart';

void main() {
  tearDown(TrackingConsentService.resetForTest);

  group('TrackingConsentService NPA (non-personalized ads)', () {
    test('uses personalized ads when tracking is authorized', () async {
      TrackingConsentService.setTestOverrideUseNpa(false);

      final npa = await TrackingConsentService.shouldUseNonPersonalizedAds();
      final request = await TrackingConsentService.buildAdRequest();

      expect(npa, isFalse);
      expect(request.nonPersonalizedAds, isFalse);
    });

    test('uses non-personalized ads when user denies tracking (Ask App Not to Track)',
        () async {
      TrackingConsentService.setTestOverrideUseNpa(true);

      final npa = await TrackingConsentService.shouldUseNonPersonalizedAds();
      final request = await TrackingConsentService.buildAdRequest();

      expect(npa, isTrue);
      expect(request.nonPersonalizedAds, isTrue);
    });

    test('buildAdRequestForTest reflects denied tracking for AdMob NPA', () {
      final request = TrackingConsentService.buildAdRequestForTest(
        nonPersonalizedAds: true,
      );
      expect(request.nonPersonalizedAds, isTrue);
    });

    test('notSupported tracking status uses non-personalized ads', () async {
      TrackingConsentService.setTestOverrideUseNpa(true);
      final request = await TrackingConsentService.buildAdRequest();
      expect(request.nonPersonalizedAds, isTrue);
    });
  });
}
