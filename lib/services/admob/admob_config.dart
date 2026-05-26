import 'dart:io';

/// Production AdMob identifiers (not test mode).
class AdMobConfig {
  AdMobConfig._();

  static const String iosAppId = 'ca-app-pub-7946568055700818~9590332986';
  static const String androidAppId = 'ca-app-pub-7946568055700818~1711842966';

  static const String iosAppOpenAdUnitId =
      'ca-app-pub-7946568055700818/5853582191';
  static const String androidAppOpenAdUnitId =
      'ca-app-pub-7946568055700818/9458471042';

  static const String iosInterstitialAdUnitId =
      'ca-app-pub-7946568055700818/8336961061';
  static const String androidInterstitialAdUnitId =
      'ca-app-pub-7946568055700818/4399688279';

  static String get appOpenAdUnitId =>
      Platform.isIOS ? iosAppOpenAdUnitId : androidAppOpenAdUnitId;

  static String get interstitialAdUnitId =>
      Platform.isIOS ? iosInterstitialAdUnitId : androidInterstitialAdUnitId;

  /// App open ads expire after four hours (AdMob guidance).
  static const Duration appOpenMaxCacheAge = Duration(hours: 4);
}
