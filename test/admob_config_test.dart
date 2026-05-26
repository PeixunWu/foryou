import 'package:flutter_test/flutter_test.dart';
import 'package:foryou/services/admob/admob_config.dart';

void main() {
  test('production AdMob app and app-open unit IDs are configured', () {
    expect(AdMobConfig.iosAppId, startsWith('ca-app-pub-'));
    expect(AdMobConfig.androidAppId, startsWith('ca-app-pub-'));
    expect(AdMobConfig.iosAppOpenAdUnitId, contains('/'));
    expect(AdMobConfig.androidAppOpenAdUnitId, contains('/'));
    expect(AdMobConfig.iosInterstitialAdUnitId, isNotEmpty);
    expect(AdMobConfig.androidInterstitialAdUnitId, isNotEmpty);
  });

  test('app open cache max age is four hours per AdMob guidance', () {
    expect(AdMobConfig.appOpenMaxCacheAge, const Duration(hours: 4));
  });
}
