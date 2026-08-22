import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../assistant/presentation/assistant_circle.dart';
import '../../assistant/presentation/assistant_overlay.dart';
import '../../assistant/state/assistant_controller.dart';
import '../../assistant/state/assistant_state.dart';

/// The main tab. Deliberately quiet - a big idle Weby orb, a tap-to-talk
/// affordance, and a couple of example commands. The full Flutter app is
/// the settings/management surface (per spec); this tab is not meant to
/// be a chat screen people live in.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final assistant = ref.watch(assistantControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('Hi${user != null ? ', ${user.name.split(' ').first}' : ''}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => ref.read(assistantControllerProvider.notifier).openOverlay(),
                  child: const AssistantCircle(state: AssistantVisualState.idle, size: 200),
                ),
                const SizedBox(height: 28),
                Text('Say "Weby" or tap to talk', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text(
                  'Try: "Weby, what is quantum computing?"',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          // The overlay is stacked here so its entrance/exit reads exactly
          // like the real floating system overlay would.
          const AssistantOverlay(),
        ],
      ),
      floatingActionButton: assistant.isOverlayVisible
          ? null
          : FloatingActionButton.large(
              backgroundColor: AppColors.glowViolet,
              onPressed: () => ref.read(assistantControllerProvider.notifier).openOverlay(),
              child: const Icon(Icons.mic_none_rounded, size: 28),
            ),
    );
  }
}
