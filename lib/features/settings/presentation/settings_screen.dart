import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

/// The full-screen Flutter app's primary role, per the product spec:
/// this is the Weby "control center", not a chat window. Sections map
/// directly to spec section 33.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sections = <_SettingsEntry>[
      _SettingsEntry('Account', Icons.person_outline, '/profile'),
      _SettingsEntry('Assistant', Icons.auto_awesome_outlined, '/settings/assistant'),
      _SettingsEntry('Contacts', Icons.contacts_outlined, '/settings/contacts'),
      _SettingsEntry('Privacy', Icons.shield_outlined, '/settings/privacy'),
      _SettingsEntry('History', Icons.history, '/history'),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: sections.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final entry = sections[i];
          return Card(
            child: ListTile(
              leading: Icon(entry.icon, color: AppColors.glowCyan),
              title: Text(entry.label),
              trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
              onTap: () => context.push(entry.route),
            ),
          );
        },
      ),
    );
  }
}

class _SettingsEntry {
  _SettingsEntry(this.label, this.icon, this.route);
  final String label;
  final IconData icon;
  final String route;
}
