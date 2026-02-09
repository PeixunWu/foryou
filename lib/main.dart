import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'config/gemini_config.dart';
import 'screens/analysis_screen.dart';
import 'screens/coach_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/history_screen.dart';
import 'screens/notification_settings_screen.dart';
import 'screens/routine_detail_screen.dart';
import 'screens/scanner_screen.dart';
import 'screens/compare_skin_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ForyouApp());
}

class ForyouApp extends StatelessWidget {
  const ForyouApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final state = AppState();
        state.loadHistory();
        return state;
      },
      child: Consumer<AppState>(
        builder: (context, state, _) {
          return MaterialApp(
            title: 'Foru AI',
            debugShowCheckedModeBanner: false,
            themeMode: ThemeMode.light,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF45A17E),
                brightness: Brightness.light,
                primary: const Color(0xFF45A17E),
              ),
              scaffoldBackgroundColor: const Color(0xFFF6F8F7),
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF45A17E),
                brightness: Brightness.dark,
                primary: const Color(0xFF45A17E),
              ),
              useMaterial3: true,
            ),
            initialRoute: '/',
            routes: {
              '/': (context) => const MainShell(),
              '/scanner': (context) => const ScannerScreen(),
              '/analysis': (context) {
                final args = ModalRoute.of(context)?.settings.arguments;
                final recordId = args is String ? args : null;
                return AnalysisScreen(recordId: recordId);
              },
              '/routine': (context) => const RoutineDetailScreen(),
              '/notification_settings': (context) => const NotificationSettingsScreen(),
              '/compare_skin': (context) => const CompareSkinScreen(),
              '/settings': (context) => const SettingsScreen(),
            },
          );
        },
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  Widget? _scannerScreen;

  Widget _screenAt(int index) {
    switch (index) {
      case 0:
        return const DashboardScreen();
      case 1:
        return _scannerScreen ?? const Center(child: CircularProgressIndicator());
      case 2:
        return const HistoryScreen();
      case 3:
        return const CoachScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F7),
      body: IndexedStack(
        index: context.watch<AppState>().selectedTabIndex,
        children: [
          _screenAt(0),
          _screenAt(1),
          _screenAt(2),
          _screenAt(3),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(5),
            topRight: Radius.circular(5),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black12, blurRadius: 4, spreadRadius: 0),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(5),
            topRight: Radius.circular(5),
          ),
          child: NavigationBar(
            selectedIndex: context.watch<AppState>().selectedTabIndex,
            onDestinationSelected: (i) {
              if (i == 1 && _scannerScreen == null) {
                setState(() {
                  _scannerScreen = const ScannerScreen();
                });
              }
              context.read<AppState>().setTabIndex(i);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.auto_awesome_outlined),
                selectedIcon: Icon(Icons.auto_awesome_rounded),
                label: 'Glow',
              ),
              NavigationDestination(
                icon: Icon(Icons.history_outlined),
                selectedIcon: Icon(Icons.history),
                label: 'History',
              ),
              NavigationDestination(
                icon: Icon(Icons.bubble_chart_outlined),
                selectedIcon: Icon(Icons.bubble_chart_rounded),
                label: 'Assistant',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
