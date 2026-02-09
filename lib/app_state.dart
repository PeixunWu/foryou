import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

import 'models/analysis_record.dart';
import 'models/coach_message.dart';
import 'services/gemini_service.dart';
export 'services/gemini_service.dart';
import 'services/uv_service.dart';


class AppState extends ChangeNotifier {
  static const _historyKey = 'foryou_analysis_history';
  static const _routineKey = 'foryou_daily_routine';
  static const _lastActiveDayKey = 'foryou_last_active_day';
  static const _notifSoundKey = 'foryou_notif_sound';
  static const _notifOffsetKey = 'foryou_notif_offset';
  static const _skinScoreKey = 'foryou_skin_score';
  static const _skinStatusKey = 'foryou_skin_status';
  static const _skinSubtitleKey = 'foryou_skin_subtitle';
  static const _hasUploadedSkinKey = 'foryou_has_uploaded_skin';
  static const _coachHistoryKey = 'foryou_coach_history';
  static const _isDarkKey = 'foryou_is_dark';
  static const _hasPermissionKey = 'foryou_has_permission';

  AppState() {
    _initNotifications();
    _loadPreferences();
  }

  late final GeminiService _gemini = GeminiService();
  GeminiService get gemini => _gemini;

  // Notifications
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _notificationsEnabled = false;
  bool get notificationsEnabled => _notificationsEnabled;
  bool _hasPermissionBeenGranted = false;
  bool get hasPermissionBeenGranted => _hasPermissionBeenGranted;

  String _notificationSound = 'default'; // 'default', 'chime', 'hero'
  String get notificationSound => _notificationSound;
  
  // Offset in minutes: 0 = exact, -5 = 5 min before, 15 = 15 min after
  int _notificationOffset = 0; 
  int get notificationOffset => _notificationOffset;

  Future<void> _initNotifications() async {
    tz.initializeTimeZones();
    final String timeZoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName));

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestSoundPermission: false,
      requestBadgePermission: false,
      requestAlertPermission: false,
    );

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _notificationsPlugin.initialize(initializationSettings);
    await refreshNotificationPermissionStatus();
  }

  Future<void> refreshNotificationPermissionStatus() async {
    if (Platform.isIOS) {
      final bool? result = await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      _notificationsEnabled = result ?? false;
    } else if (Platform.isAndroid) {
       final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
       final bool? granted = await androidImplementation?.requestNotificationsPermission();
       _notificationsEnabled = granted ?? false;
    }
    if (_notificationsEnabled) {
      _hasPermissionBeenGranted = true;
      _savePreferences();
    }
    notifyListeners();
  }

  Future<void> requestNotificationPermissions() async {
    if (Platform.isIOS) {
      final bool? result = await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      _notificationsEnabled = result ?? false;
    } else if (Platform.isAndroid) {
       final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      final bool? granted = await androidImplementation?.requestNotificationsPermission();
      _notificationsEnabled = granted ?? false;
    }
    if (_notificationsEnabled) {
      _hasPermissionBeenGranted = true;
      _savePreferences();
    }
    notifyListeners();
  }

  Future<void> setNotificationSound(String sound) async {
    _notificationSound = sound;
    _savePreferences();
    notifyListeners();
  }

  Future<void> setNotificationOffset(int offset) async {
    _notificationOffset = offset;
    _savePreferences();
    _rescheduleAllNotifications();
    notifyListeners();
  }

  bool _hasUploadedSkinPhoto = false;
  bool get hasUploadedSkinPhoto => _hasUploadedSkinPhoto;

  int _dailySkinScore = 0;
  int get dailySkinScore => _dailySkinScore;
  set dailySkinScore(int v) {
    _dailySkinScore = v;
    _saveSkinHealth();
    notifyListeners();
  }

  // Dashboard Data
  String _insightTitle = 'Skincare Tip';
  String get insightTitle => _insightTitle;
  String _insightOfTheDay = 'The UV index is high (7.2) today in your area. Reapply your mineral sunscreen.';
  String get insightOfTheDay => _insightOfTheDay;
  set insightOfTheDay(String v) {
    _insightOfTheDay = v;
    notifyListeners();
  }

  String _skinHealthStatus = 'Check Up Needed';
  String get skinHealthStatus => _skinHealthStatus;
  set skinHealthStatus(String v) {
    _skinHealthStatus = v;
    _saveSkinHealth();
    notifyListeners();
  }

  String _skinHealthSubtitle =
      'Upload a skin photo to start tracking your health.';
  String get skinHealthSubtitle => _skinHealthSubtitle;
  set skinHealthSubtitle(String v) {
    _skinHealthSubtitle = v;
    _saveSkinHealth();
    notifyListeners();
  }

  List<RoutineItem> _morningRoutine = [];
  List<RoutineItem> get morningRoutine => List.unmodifiable(_morningRoutine);

  void toggleRoutine(int index) {
    _morningRoutine[index].done = !_morningRoutine[index].done;
    _saveRoutines();
    notifyListeners();
  }

  void addRoutineItem(String label, [String time = '', String details = '']) {
    final newItem = RoutineItem(label, false, time, details);
    _morningRoutine.add(newItem);
    _saveRoutines();
    
    if (time.isNotEmpty) {
      _scheduleNotification(newItem);
    }
    notifyListeners();
  }
  
  void removeRoutineItem(int index) {
    if (index >= 0 && index < _morningRoutine.length) {
      final item = _morningRoutine[index];
      _morningRoutine.removeAt(index);
      _saveRoutines();
      // Remove notification? Hashcode ID might be tricky if not stored.
      // Re-schedule all to be safe and clean up
      _rescheduleAllNotifications(); 
      notifyListeners();
    }
  }

  // Routine Persistence & Logic
  Future<void> _loadRoutines() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Check Daily Reset
    final lastDay = prefs.getInt(_lastActiveDayKey) ?? 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    
    bool shouldReset = lastDay != today;
    if (shouldReset) {
      prefs.setInt(_lastActiveDayKey, today);
    }

    // Load Items
    final raw = prefs.getString(_routineKey);
    if (raw != null) {
      final list = jsonDecode(raw) as List<dynamic>;
      _morningRoutine = list.map((e) => RoutineItem.fromJson(e)).toList();
    } else {
      // Start empty if fresh install
      _morningRoutine = [];
    }

    if (shouldReset) {
      for (var item in _morningRoutine) {
        item.done = false;
      }
      _saveRoutines(); // Save the reset state
    }
    notifyListeners();
  }

  Future<void> _loadPreferences() async {
      final prefs = await SharedPreferences.getInstance();
      _notificationSound = prefs.getString(_notifSoundKey) ?? 'default';
      if (_notificationSound == 'upbeat') _notificationSound = 'default';
      _notificationOffset = prefs.getInt(_notifOffsetKey) ?? 0;
      _hasPermissionBeenGranted = prefs.getBool(_hasPermissionKey) ?? false;
      await _loadSkinHealth();
      await loadHistory();
      await _loadRoutines();
      await _loadCoachHistory();
      notifyListeners();
  }

  Future<void> _saveRoutines() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _morningRoutine.map((e) => e.toJson()).toList();
    await prefs.setString(_routineKey, jsonEncode(list));
  }
  
  Future<void> _savePreferences() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_notifSoundKey, _notificationSound);
      await prefs.setInt(_notifOffsetKey, _notificationOffset);
      await prefs.setBool(_hasPermissionKey, _hasPermissionBeenGranted);
  }

  Future<void> _loadCoachHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_coachHistoryKey);
    if (data != null) {
      try {
        final List<dynamic> decoded = jsonDecode(data);
        _coachHistory.clear();
        _coachHistory.addAll(decoded.map((e) => CoachMessage.fromJson(e)));
      } catch (_) {}
    }
  }

  Future<void> _saveCoachHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(_coachHistory.map((e) => e.toJson()).toList());
    await prefs.setString(_coachHistoryKey, data);
  }

  Future<void> _loadSkinHealth() async {
    final prefs = await SharedPreferences.getInstance();
    _hasUploadedSkinPhoto = prefs.getBool(_hasUploadedSkinKey) ?? false;
    if (_hasUploadedSkinPhoto) {
      _dailySkinScore = prefs.getInt(_skinScoreKey) ?? 0;
      _skinHealthStatus = prefs.getString(_skinStatusKey) ?? 'Check Up Needed';
      _skinHealthSubtitle = prefs.getString(_skinSubtitleKey) ?? 'Analyzing your results...';
    }
    notifyListeners();
  }

  Future<void> _saveSkinHealth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasUploadedSkinKey, _hasUploadedSkinPhoto);
    await prefs.setInt(_skinScoreKey, _dailySkinScore);
    await prefs.setString(_skinStatusKey, _skinHealthStatus);
    await prefs.setString(_skinSubtitleKey, _skinHealthSubtitle);
  }

  Future<void> _scheduleNotification(RoutineItem item) async {
    if (item.time.isEmpty) return;
    
    // Parse time string "HH:mm AM/PM"
    final parsedTime = _parseTime(item.time);
    if (parsedTime == null) return;

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      parsedTime.hour,
      parsedTime.minute,
    );
    
    // Configure Offset
    scheduledDate = scheduledDate.add(Duration(minutes: _notificationOffset));

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    
    // Generate a unique ID hash based on label
    final id = item.label.hashCode;

    await _notificationsPlugin.zonedSchedule(
      id,
      'Routine Reminder',
      'Time for: ${item.label}',
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
            'routine_channel_v2', 'Routine Reminders', // Version update triggers re-creation
            channelDescription: 'Reminders for daily routine items',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            // Re-map the sound string to actual resource if available, else default.
            // Note: For custom sounds, they must be in res/raw for Android.
            // For now, we'll stick to high importance for "floating" effect.
        ),
        iOS: DarwinNotificationDetails(
           presentAlert: true,
           presentBadge: true,
           presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // Repeat daily
    );
  }
  
  Future<void> _rescheduleAllNotifications() async {
      await _notificationsPlugin.cancelAll();
      for (var item in _morningRoutine) {
          if (item.time.isNotEmpty) {
              await _scheduleNotification(item);
          }
      }
  }

  DateTime? _parseTime(String timeStr) {
    try { 
      // Expected format: "7:30 AM"
      final parts = timeStr.trim().split(' '); // ["7:30", "AM"]
      if (parts.length != 2) return null;
      
      final timeParts = parts[0].split(':'); // ["7", "30"]
      int hour = int.parse(timeParts[0]);
      int minute = int.parse(timeParts[1]);
      final period = parts[1].toUpperCase();

      if (period == 'PM' && hour != 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;
      
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day, hour, minute);
    } catch (e) {
      return null;
    }
  }

  ScanAnalysis? _lastAnalysis;
  Uint8List? _lastScanImage;
  ScanMode? _lastScanMode;
  ScanAnalysis? get lastAnalysis => _lastAnalysis;
  Uint8List? get lastScanImage => _lastScanImage;
  ScanMode? get lastScanMode => _lastScanMode;

  List<AnalysisRecord> _analysisHistory = [];
  List<AnalysisRecord> get analysisHistory => List.unmodifiable(_analysisHistory);

  List<AnalysisRecord> get skinHistory => 
      _analysisHistory.where((r) => r.analysis.mode == ScanMode.skin).toList();

  Future<void> loadHistory() async {
    fetchCurrentUV(); // Start fetching UV
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_historyKey);
      if (raw == null) return;
      final list = jsonDecode(raw) as List<dynamic>?;
      if (list == null) return;
      
      _analysisHistory = [];
      for (final e in list) {
        final record = await AnalysisRecord.fromJson(Map<String, dynamic>.from(e as Map));
        if (record != null) {
          _analysisHistory.add(record);
        }
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _analysisHistory.map((r) => r.toJson()).toList();
      await prefs.setString(_historyKey, jsonEncode(list));
    } catch (_) {}
  }

  void deleteHistoryRecord(String id) {
    _analysisHistory.removeWhere((r) => r.id == id);
    _saveHistory();
    notifyListeners();
  }

  Future<void> setScanResult(ScanAnalysis a, Uint8List image, ScanMode mode) async {
    _lastAnalysis = a;
    _lastScanImage = image;
    _lastScanMode = mode;
    
    // Save image to file
    String? path;
    try {
       final dir = await getApplicationDocumentsDirectory();
       final timestamp = DateTime.now().millisecondsSinceEpoch;
       final file = File('${dir.path}/analysis_$timestamp.jpg');
       await file.writeAsBytes(image);
       path = file.path;
    } catch (_) {}
    final record = AnalysisRecord(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      analysis: a,
      imageBytes: image,
      createdAt: DateTime.now(),
      imagePath: path,
    );
    _analysisHistory.insert(0, record);
    
    // Update dashboard metrics if it's a skin scan
    if (mode == ScanMode.skin) {
      _hasUploadedSkinPhoto = true;
      _dailySkinScore = a.skinScore ?? 85; // Use AI provided score or default
      _skinHealthStatus = a.skinStatus ?? a.name;
      _skinHealthSubtitle = a.callToAction ?? a.whatIsIt;
      await _saveSkinHealth();
    }

    await _saveHistory();
    notifyListeners();
  }

  AnalysisRecord? getRecordById(String id) {
    try {
      return _analysisHistory.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  void clearScanResult() {
    _lastAnalysis = null;
    _lastScanImage = null;
    _lastScanMode = null;
    notifyListeners();
  }

  String? _userSkinProfile = 'Combination, sensitive to fragrance';
  String? get userSkinProfile => _userSkinProfile;
  set userSkinProfile(String? v) {
    _userSkinProfile = v;
    notifyListeners();
  }

  Uint8List? _day1SkinPhoto;
  Uint8List? get day1SkinPhoto => _day1SkinPhoto;
  set day1SkinPhoto(Uint8List? v) {
    _day1SkinPhoto = v;
    notifyListeners();
  }

  Uint8List? _day7SkinPhoto;
  Uint8List? get day7SkinPhoto => _day7SkinPhoto;
  set day7SkinPhoto(Uint8List? v) {
    _day7SkinPhoto = v;
    notifyListeners();
  }

  String _progressComparison = '';
  String get progressComparison => _progressComparison;
  set progressComparison(String v) {
    _progressComparison = v;
    notifyListeners();
  }

  final List<CoachMessage> _coachHistory = [];
  List<CoachMessage> get coachHistory => List.unmodifiable(_coachHistory);
  
  String _coachReply = '';
  String get coachReply => _coachReply;
  bool _coachLoading = false;
  bool get coachLoading => _coachLoading;

  ScanMode? _preferredScannerMode;
  ScanMode? get preferredScannerMode => _preferredScannerMode;
  set preferredScannerMode(ScanMode? v) {
    _preferredScannerMode = v;
    notifyListeners();
  }

  // Navigation Control
  int _selectedTabIndex = 0;
  int get selectedTabIndex => _selectedTabIndex;

  void setTabIndex(int index) {
    _selectedTabIndex = index;
    notifyListeners();
  }

  void clearCoachHistory() {
    _coachHistory.clear();
    _saveCoachHistory();
    _coachReply = '';
    notifyListeners();
  }

  Future<void> clearAnalysisHistory() async {
    _analysisHistory = [];
    _hasUploadedSkinPhoto = false;
    _dailySkinScore = 0;
    _skinHealthStatus = 'Check Up Needed';
    _skinHealthSubtitle = 'Upload a skin photo to start tracking your health.';
    await _saveHistory();
    await _saveSkinHealth();
    notifyListeners();
  }

  final _uvService = UVService();

  Future<void> fetchCurrentUV() async {
    final data = await _uvService.getCurrentUV();
    if (data != null) {
      final uv = data['uv'] as num;
      _updateInsightForUV(uv.toDouble());
    }
  }

  void _updateInsightForUV(double uv) {
    if (uv <= 2) {
      _insightTitle = 'Low UV Index ($uv)';
      _insightOfTheDay = 'UV levels are low. No special protection needed, but SPF 15 is recommended for long exposure.';
    } else if (uv <= 5) {
      _insightTitle = 'Moderate UV Index ($uv)';
      _insightOfTheDay = 'Moderate UV levels. Apply SPF 30+ broad-spectrum sunscreen before going outside.';
    } else if (uv <= 7) {
      _insightTitle = 'High UV Index ($uv)';
      _insightOfTheDay = 'High UV! Protection essential. Apply SPF 50+ every 2 hours and wear a hat.';
    } else {
      _insightTitle = 'Extreme UV Index ($uv)';
      _insightOfTheDay = 'Extreme UV risk! Use SPF 50+ mineral sunscreen. Avoid sun between 10AM-4PM.';
    }
    notifyListeners();
  }

  Future<void> fetchInsight() async {
    try {
      final s = await _gemini.getInsightOfTheDay(
        _dailySkinScore,
        'Last scan: ${_lastScanMode?.name ?? "none"}',
      );
      _insightOfTheDay = s;
      notifyListeners();
    } catch (_) {
      _insightOfTheDay = 'Your skin is looking great today!';
      notifyListeners();
    }
  }

  Future<void> sendCoachMessage(String message) async {
    if (message.trim().isEmpty) return;
    
    final userMsg = CoachMessage(text: message, isUser: true, timestamp: DateTime.now());
    _coachHistory.add(userMsg);
    
    _coachLoading = true;
    notifyListeners();
    
    try {
      // For Gemini, we might still want to pass recent history simplified or the new model.
      // Let's adapt the coachChat params to take simpler list if needed.
      final historyForGemini = _coachHistory.where((m) => m != userMsg).map((m) => MapEntry(m.isUser ? m.text : '', !m.isUser ? m.text : '')).toList();
      // Actually, MapEntry is key-value, usually user-model pairs. 
      // Let's refine how we pass history to gemini service if it expects specific user/model pairs.
      
      final replyText = await _gemini.coachChat(_getGeminiHistory(), message);
      
      final assistantMsg = CoachMessage(text: replyText, isUser: false, timestamp: DateTime.now());
      _coachHistory.add(assistantMsg);
      
      _coachReply = replyText;
      _coachLoading = false;
      _saveCoachHistory();
      notifyListeners();
    } catch (e) {
      _coachReply = 'Something went wrong. Please try again.';
      _coachLoading = false;
      notifyListeners();
    }
  }

  List<MapEntry<String, String>> _getGeminiHistory() {
    List<MapEntry<String, String>> history = [];
    // Assistant view history is just an alternating list of User and AI. 
    // gemini.chat expects Content history usually. 
    // For now we preserve the list of MapEntry if gemini service uses it.
    for (int i = 0; i < _coachHistory.length - 1; i += 2) {
       if (i + 1 < _coachHistory.length) {
         history.add(MapEntry(_coachHistory[i].text, _coachHistory[i+1].text));
       }
    }
    return history;
  }

  Future<void> runProgressComparison() async {
    if (_day1SkinPhoto == null || _day7SkinPhoto == null) return;
    try {
      final text = await _gemini.compareSkinSideBySide(_day1SkinPhoto!, _day7SkinPhoto!);
      _progressComparison = text;
      notifyListeners();
    } catch (_) {
      _progressComparison = 'Comparison could not be completed.';
      notifyListeners();
    }
  }

  Future<String> compareTwoRecords(AnalysisRecord r1, AnalysisRecord r2) async {
    // r1 is older, r2 is newer based on index usually? 
    // Let's assume the caller passes them correctly or we sort by date.
    final items = [r1, r2]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return await _gemini.compareSkinSideBySide(items[0].imageBytes, items[1].imageBytes);
  }
}

class RoutineItem {
  RoutineItem(this.label, this.done, [this.time = '', this.details = '']);
  final String label;
  bool done;
  final String time;
  final String details;

  Map<String, dynamic> toJson() => {
    'label': label,
    'done': done,
    'time': time,
    'details': details,
  };

  factory RoutineItem.fromJson(Map<String, dynamic> json) => RoutineItem(
    json['label'] as String,
    json['done'] as bool,
    json['time'] as String? ?? '',
    json['details'] as String? ?? '',
  );
}
