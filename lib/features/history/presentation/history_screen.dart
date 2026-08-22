import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../data/conversation_repository.dart';

final _conversationsProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(conversationRepositoryProvider).list();
});

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(_conversationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: conversationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text('Could not load history: $err', style: const TextStyle(color: AppColors.textSecondary)),
        ),
        data: (conversations) {
          if (conversations.isEmpty) {
            return const Center(
              child: Text('No conversations yet', style: TextStyle(color: AppColors.textSecondary)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: conversations.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final c = conversations[i];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.forum_outlined, color: AppColors.glowCyan),
                  title: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(_formatDate(c.updatedAt), style: const TextStyle(color: AppColors.textMuted)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppColors.textMuted),
                    onPressed: () async {
                      await ref.read(conversationRepositoryProvider).delete(c.id);
                      ref.invalidate(_conversationsProvider);
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
