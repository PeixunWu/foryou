import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().refreshNotificationPermissionStatus();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F7),
      appBar: AppBar(
        title: const Text('Notifications'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Consumer<AppState>(
        builder: (context, state, _) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (!state.notificationsEnabled && !state.hasPermissionBeenGranted) ...[
                _buildSectionHeader(context, 'Permissions'),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.notifications_active_outlined),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                'Allow Notifications',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            TextButton(
                              onPressed: () => state.requestNotificationPermissions(),
                              child: const Text('Enable', style: TextStyle(color: Color(0xFF45A17E), fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Ensure you grant permissions to receive daily routine reminders.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
              
              _buildSectionHeader(context, 'Timing Preference'),
              Container(
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
                child: Column(
                  children: [
                    _buildRadioTile<int>(
                      title: 'Exactly at time',
                      value: 0,
                      groupValue: state.notificationOffset,
                      onChanged: (v) => state.setNotificationOffset(v!),
                    ),
                    const Divider(height: 1),
                    _buildRadioTile<int>(
                      title: '5 minutes before',
                      value: -5,
                      groupValue: state.notificationOffset,
                      onChanged: (v) => state.setNotificationOffset(v!),
                    ),
                    const Divider(height: 1),
                     _buildRadioTile<int>(
                      title: '15 minutes before',
                      value: -15,
                      groupValue: state.notificationOffset,
                      onChanged: (v) => state.setNotificationOffset(v!),
                    ),
                    const Divider(height: 1),
                     _buildRadioTile<int>(
                      title: '30 minutes before',
                      value: -30,
                      groupValue: state.notificationOffset,
                      onChanged: (v) => state.setNotificationOffset(v!),
                    ),
                     const Divider(height: 1),
                     _buildRadioTile<int>(
                      title: '1 hour before',
                      value: -60,
                      groupValue: state.notificationOffset,
                      onChanged: (v) => state.setNotificationOffset(v!),
                    ),
                    const Divider(height: 1),
                     _buildRadioTile<int>(
                      title: '15 minutes after',
                      value: 15,
                      groupValue: state.notificationOffset,
                      onChanged: (v) => state.setNotificationOffset(v!),
                    ),
                    const Divider(height: 1),
                     _buildRadioTile<int>(
                      title: '30 minutes after',
                      value: 30,
                      groupValue: state.notificationOffset,
                      onChanged: (v) => state.setNotificationOffset(v!),
                    ),
                    const Divider(height: 1),
                     _buildRadioTile<int>(
                      title: '1 hour after',
                      value: 60,
                      groupValue: state.notificationOffset,
                      onChanged: (v) => state.setNotificationOffset(v!),
                    ),
                  ],
                ),
              ),
               const SizedBox(height: 40),
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
              color: Colors.grey[700],
            ),
      ),
    );
  }

  Widget _buildRadioTile<T>({
    required String title,
    required T value,
    required T groupValue,
    required ValueChanged<T?> onChanged,
  }) {
    return Theme(
      data: Theme.of(context).copyWith(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: RadioListTile<T>(
        value: value,
        groupValue: groupValue,
        onChanged: onChanged,
        title: Text(title),
        dense: true,
        activeColor: const Color(0xFF45A17E),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
    );
  }
}
