import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Read the auth state cleanly
    final authState = ref.watch(authControllerProvider);
    
    // Adjust if your state is AsyncValue (e.g., authState.valueOrNull?.user)
    final user = authState.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: AppColors.surfaceElevated,
                  backgroundImage: user?.avatarUrl != null ? NetworkImage(user!.avatarUrl!) : null,
                  child: user?.avatarUrl == null
                      ? Text(
                          (user?.name.isNotEmpty ?? false) ? user!.name[0].toUpperCase() : '?',
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
                        )
                      : null,
                ),
                const SizedBox(height: 14),
                Text(user?.name ?? '', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(user?.email ?? '', style: const TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.verified_user_outlined),
                  title: const Text('Authentication method'),
                  trailing: Text(
                    user?.authProvider ?? '',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.mark_email_read_outlined),
                  title: const Text('Email verified'),
                  trailing: Icon(
                    user?.emailVerified == true ? Icons.check_circle : Icons.error_outline,
                    color: user?.emailVerified == true ? AppColors.success : AppColors.warning,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            icon: const Icon(Icons.logout, color: AppColors.error),
            label: const Text('Log out', style: TextStyle(color: AppColors.error)),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Log out everywhere?'),
                  content: const Text('This will sign you out on every device using this account.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Log out all')),
                  ],
                ),
              );
              if (confirmed == true) {
                // ignore: use_build_context_synchronously
                await ref.read(authControllerProvider.notifier).logoutAllDevices();
              }
            },
            child: const Text('Log out of all devices'),
          ),
        ],
      ),
    );
  }
}
