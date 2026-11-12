import 'package:flutter/material.dart';

/// Notifications page, opened from the bell on Home. The backend has no notifications
/// feature yet, so this always shows the empty state. When it does, load the list here.
class NotificationsView extends StatelessWidget {
  const NotificationsView({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.notifications_none_rounded, size: 64, color: theme.colorScheme.primary.withValues(alpha: 0.5)),
              const SizedBox(height: 16),
              Text('No notifications yet', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                "You're all caught up. New activity will show up here.",
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
