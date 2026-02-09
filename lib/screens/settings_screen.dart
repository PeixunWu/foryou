import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      body: Consumer<AppState>(
        builder: (context, state, _) {
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              _buildSectionHeader(context, 'Account & App'),
              _buildSettingsCard(context, [
                _buildNavigationTile(
                  context: context,
                  icon: Icons.info_outline,
                  title: 'About Foryou AI',
                  onTap: () => _showInfoDialog(context),
                ),
                const Divider(height: 1),
                _buildNavigationTile(
                  context: context,
                  icon: Icons.notifications_none_outlined,
                  title: 'Notifications',
                  onTap: () => Navigator.of(context).pushNamed('/notification_settings'),
                ),
              ]),
              
              const SizedBox(height: 24),
              _buildSectionHeader(context, 'Data Management'),
              _buildSettingsCard(context, [
                _buildActionTile(
                  context: context,
                  icon: Icons.chat_bubble_outline,
                  title: 'Clear Chat History',
                  subtitle: 'Remove all AI coach messages',
                  onTap: () => _confirmClear(context, 'chat history', () => state.clearCoachHistory()),
                  isDestructive: true,
                ),
                const Divider(height: 1),
                _buildActionTile(
                  context: context,
                  icon: Icons.history_outlined,
                  title: 'Clear Scan History',
                  subtitle: 'Remove all analysis records',
                  onTap: () => _confirmClear(context, 'scan history', () => state.clearAnalysisHistory()),
                  isDestructive: true,
                ),
              ]),

              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary.withAlpha(200),
            ),
      ),
    );
  }

  Widget _buildSettingsCard(BuildContext context, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }


  Widget _buildNavigationTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildActionTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? Colors.black : Theme.of(context).colorScheme.onSurfaceVariant),
      title: Text(
        title, 
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: isDestructive ? Colors.black : Theme.of(context).colorScheme.onSurface,
        ),
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      onTap: onTap,
    );
  }

  void _confirmClear(BuildContext context, String target, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Clear $target?'),
        content: Text('This action cannot be undone. Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              onConfirm();
              Navigator.pop(ctx);
            },
            child: const Text('Clear', style: TextStyle(color: Color(0xFF45A17E))),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('About', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Foryou AI is your personal skincare and health companion, designed to help you understand your skin and build better habits.',
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 16),
              Text('Key Features:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              SizedBox(height: 8),
              _InfoBullet(icon: Icons.auto_awesome, text: 'Skin Health Tracking: Daily scans to monitor progress.'),
              _InfoBullet(icon: Icons.checklist, text: 'Routine Management: Personalized morning and evening routines.'),
              _InfoBullet(icon: Icons.bubble_chart, text: 'AI Coaching: Expert advice on skincare and nutrition.'),
              _InfoBullet(icon: Icons.wb_sunny, text: 'UV Awareness: Real-time insights based on your location.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: Color(0xFF45A17E))),
          ),
        ],
      ),
    );
  }
}

class _InfoBullet extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoBullet({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF45A17E)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
