import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Explanatory, non-toggle-only privacy screen - the spec asks that
/// privacy controls be "understandable", not just a wall of switches.
class PrivacySettingsScreen extends StatelessWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        'Contacts stay on your device',
        'Weby reads your contacts locally to resolve commands like "call my bro". '
            'Your contact list is never uploaded to Weby\'s servers.',
        Icons.contacts_outlined,
      ),
      (
        'Wake word runs locally',
        'Listening for "Weby" happens on-device. Audio is only sent to the cloud '
            'after the wake word triggers and you ask something that needs AI.',
        Icons.mic_none_outlined,
      ),
      (
        'Conversation history',
        'AI conversations can be saved to your account so they sync across devices. '
            'You can delete any conversation at any time from History.',
        Icons.forum_outlined,
      ),
      (
        'AI provider keys never touch this app',
        'Requests to Gemini/Hugging Face are made by Weby\'s backend using '
            'server-held credentials - your device never sees a provider API key.',
        Icons.vpn_key_outlined,
      ),
      (
        'Voice verification is a convenience, not a lock',
        'It estimates whether it\'s likely you speaking. For anything sensitive, '
            'Weby relies on your device\'s own authentication (PIN/biometrics).',
        Icons.verified_user_outlined,
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Privacy')),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final item = items[i];
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(item.$3, color: AppColors.glowCyan),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.$1, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16)),
                        const SizedBox(height: 6),
                        Text(item.$2, style: const TextStyle(color: AppColors.textSecondary, height: 1.4)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
