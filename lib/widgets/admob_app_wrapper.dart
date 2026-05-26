import 'package:flutter/material.dart';

import '../services/admob/admob_initializer.dart';
import '../services/admob/app_open_ad_manager.dart';
import '../services/admob/tracking_consent_service.dart';

/// Requests ATT (iOS/iPad) then triggers the first app-open ad load/show.
class AdMobAppWrapper extends StatefulWidget {
  const AdMobAppWrapper({super.key, required this.child});

  final Widget child;

  @override
  State<AdMobAppWrapper> createState() => _AdMobAppWrapperState();
}

class _AdMobAppWrapperState extends State<AdMobAppWrapper>
    with WidgetsBindingObserver {
  bool _attRequested = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onFirstFrame());
  }

  Future<void> _onFirstFrame() async {
    if (_attRequested) return;
    _attRequested = true;

    // ATT first (iPhone + iPad), then start foreground ads so NPA applies when denied.
    await TrackingConsentService.requestOnLaunch();

    AdMobInitializer.startAppOpenForegroundListener();
    await AppOpenAdManager.instance.onAppForeground();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Extra resume hook for iPad when AppStateEventNotifier timing differs.
    if (state == AppLifecycleState.resumed && _attRequested) {
      // AppOpenAdManager is driven by AppStateEventNotifier; no duplicate show here.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
