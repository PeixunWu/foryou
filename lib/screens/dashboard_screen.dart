import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import 'routine_item_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final green = Theme.of(context).colorScheme.primary;
    final greenLight = green.withValues(alpha: 0.15);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F7),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: greenLight,
                      child: Icon(
                        Icons.person,
                        color: green,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          Text(
                            'Hi There',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.notifications_outlined),
                      onPressed: () => Navigator.of(context).pushNamed('/notification_settings'),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Consumer<AppState>(
                  builder: (_, state, __) => _SkinScoreCard(
                    score: state.dailySkinScore,
                    status: state.skinHealthStatus,
                    subtitle: state.skinHealthSubtitle,
                    hasScan: state.hasUploadedSkinPhoto,
                    accentColor: green,
                    onTap: () => state.setTabIndex(1), // Go to Glow tab
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Daily Routine',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 20, /* +2 size */
                          ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Consumer<AppState>(
                          builder: (_, state, __) {
                            final done = state.morningRoutine.where((e) => e.done).length;
                            final total = state.morningRoutine.length;
                            return Text(
                              '$done of $total done',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                            );
                          },
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pushNamed('/routine'),
                          child: const Text(
                            'View all',
                            style: TextStyle(color: Color(0xFF45A17E)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Consumer<AppState>(
                  builder: (_, state, __) => Container(
                    padding: state.morningRoutine.isEmpty ? const EdgeInsets.all(24) : EdgeInsets.zero,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: state.morningRoutine.isEmpty
                        ? Column(
                            children: [
                              Icon(Icons.add_task, size: 48, color: Colors.grey[300]),
                              const SizedBox(height: 12),
                              Text(
                                'No routines yet',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Add your first routine item to stay on track.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey[500],
                                    ),
                              ),
                              const SizedBox(height: 16),
                              TextButton.icon(
                                onPressed: () => Navigator.of(context).pushNamed('/routine'),
                                icon: const Icon(Icons.add, color: Color(0xFF45A17E)),
                                label: const Text(
                                  'Add Routine',
                                  style: TextStyle(color: Color(0xFF45A17E), fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: List.generate(state.morningRoutine.length, (index) {
                              final item = state.morningRoutine[index];
                              return Dismissible(
                                key: ValueKey('${item.label}_$index'), // Ensure unique key
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  color: Colors.red,
                                  child: const Icon(Icons.delete, color: Colors.white),
                                ),
                                confirmDismiss: (direction) async {
                                  return await showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        title: const Text("Delete Routine?"),
                                        content: const Text("Are you sure you want to delete this item?"),
                                        actions: <Widget>[
                                          TextButton(
                                            onPressed: () => Navigator.of(context).pop(false),
                                            child: const Text("Cancel", style: TextStyle(color: Color(0xFF45A17E))),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.of(context).pop(true),
                                            child: const Text("Delete", style: TextStyle(color: Colors.red)),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                                onDismissed: (direction) {
                                 state.removeRoutineItem(index);
                                 ScaffoldMessenger.of(context).showSnackBar(
                                   SnackBar(content: Text('${item.label} deleted')),
                                 );
                                },
                                child: _RoutineTile(
                                  label: item.label,
                                  time: item.time,
                                  done: item.done,
                                  onToggle: () => state.toggleRoutine(index),
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => RoutineItemScreen(index: index),
                                    ),
                                  ),
                                  accentColor: green,
                                  hasDivider: index != state.morningRoutine.length - 1,
                                ),
                              );
                            }),
                          ),
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Insight of the Day',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Consumer<AppState>(
                      builder: (_, state, __) => _InsightCard(
                        title: state.insightTitle,
                        message: state.insightOfTheDay,
                        accentColor: green,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Consumer<AppState>(
          builder: (_, state, __) => _QuickScanFAB(
            onTap: () {
               // Quick Scan -> Go to Glow Tab (index 1)
               state.setTabIndex(1);
            },
            accentColor: green,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class _SkinScoreCard extends StatelessWidget {
  const _SkinScoreCard({
    required this.score,
    required this.status,
    required this.subtitle,
    required this.hasScan,
    required this.accentColor,
    required this.onTap,
  });

  final int score;
  final String status;
  final String subtitle;
  final bool hasScan;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final green = accentColor;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(26),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                SizedBox(
                  width: 88,
                  height: 88,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 88,
                        height: 88,
                        child: CircularProgressIndicator(
                          value: hasScan ? (score / 100) : 0,
                          strokeWidth: 8,
                          backgroundColor: const Color(0xFFE2E8F0),
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(Color(0xFF99FFD8)),
                        ),
                      ),
                      if (hasScan)
                        Text(
                          '$score%',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: green,
                              ),
                        )
                      else
                        Icon(Icons.camera_alt_outlined, color: green, size: 32),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasScan ? status : 'Get your Glow-up',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: green,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasScan ? subtitle : 'Upload your first skin photo to see your skin health rating.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoutineTile extends StatelessWidget {
  const _RoutineTile({
    required this.label,
    required this.time,
    required this.done,
    required this.onToggle,
    required this.onTap,
    required this.accentColor,
    required this.hasDivider,
  });

  final String label;
  final String time;
  final bool done;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  final Color accentColor;
  final bool hasDivider;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap, // Opens detail view
      child: Container(
        color: Colors.transparent, // Hit test for the whole row
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            Row(
              children: [
                // Custom Checkbox - Tap separately
                GestureDetector(
                  onTap: onToggle,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: done ? const Color(0xFF99FFD8) : Colors.transparent,
                      shape: BoxShape.circle,
                      border: done
                          ? null
                          : Border.all(color: Theme.of(context).colorScheme.outline, width: 2),
                    ),
                    child: done
                        ? const Icon(Icons.check, color: Colors.black, size: 16)
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child:  Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                         // No strikethrough
                         // No grey color (or maybe keep grey if done? User said: "dont show strikethrough")
                         // Usually no strikethrough implies regular text color too, or maybe just slight dim. 
                         // I will keep regular color for clarity unless user prefers otherwise, 
                         // or maybe subtly dimmer. Let's stick to standard color.
                        ),
                    ),
                ),
                if (time.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Text(
                      time,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
              ],
            ),
            if (hasDivider) ...[
              const SizedBox(height: 12),
              Divider(height: 1, color: Colors.grey.withValues(alpha: 0.1)),
            ],
          ],
        ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.title,
    required this.message,
    required this.accentColor,
  });

  final String title;
  final String message;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F9F1), // Keep this or make white? User said "uv index alert container corner radius change to 26". 
        // User didn't explicitly say background color white for this one, but usually consistent. 
        // But "morning routine container background color change to #FFFFFF".
        // I will keep the light green tint for the alert but update radius.
        borderRadius: BorderRadius.circular(26), 
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline_rounded, color: Colors.black, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickScanFAB extends StatelessWidget {
  const _QuickScanFAB({required this.onTap, required this.accentColor});

  final VoidCallback onTap;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Color(0xFF99FFD8),
      borderRadius: BorderRadius.circular(30),
      elevation: 4,
      shadowColor: accentColor.withValues(alpha: 0.4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.document_scanner, color: Colors.black, size: 28),
              const SizedBox(width: 12),
              Text(
                'QUICK SCAN',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
