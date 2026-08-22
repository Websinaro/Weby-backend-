import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../assistant/presentation/assistant_circle.dart';
import '../../assistant/state/assistant_state.dart';

/// Shown briefly while AuthController checks for an existing session.
/// The router redirects away from here automatically once auth status
/// resolves to authenticated/unauthenticated.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const AssistantCircle(state: AssistantVisualState.idle, size: 120),
            const SizedBox(height: 24),
            Text(
              'Weby',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontSize: 28, letterSpacing: -0.5),
            ),
          ],
        ),
      ),
    );
  }
}
