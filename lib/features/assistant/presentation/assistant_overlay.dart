import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../state/assistant_controller.dart';
import '../state/assistant_state.dart';
import 'assistant_circle.dart';

/// The floating, non-blocking Weby surface described in the spec:
/// small, bottom-anchored, appears on wake, shows live transcript,
/// and disappears when done. This in-app version is the visual/UX
/// reference for the true system overlay implemented natively in the
/// Android integration stage (which uses the same Flutter widget
/// rendered inside a TYPE_APPLICATION_OVERLAY window).
class AssistantOverlay extends ConsumerStatefulWidget {
  const AssistantOverlay({super.key});

  @override
  ConsumerState<AssistantOverlay> createState() => _AssistantOverlayState();
}

class _AssistantOverlayState extends ConsumerState<AssistantOverlay> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _statusLabel(AssistantVisualState s) {
    switch (s) {
      case AssistantVisualState.idle:
        return 'Weby';
      case AssistantVisualState.listening:
        return 'Listening...';
      case AssistantVisualState.processing:
        return 'Thinking...';
      case AssistantVisualState.speaking:
        return 'Weby';
      case AssistantVisualState.executing:
        return 'On it...';
      case AssistantVisualState.error:
        return 'Something went wrong';
    }
  }

  @override
  Widget build(BuildContext context) {
    final assistant = ref.watch(assistantControllerProvider);
    final controllerNotifier = ref.read(assistantControllerProvider.notifier);

    if (!assistant.isOverlayVisible) return const SizedBox.shrink();

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: controllerNotifier.closeOverlay,
        child: Container(
          color: Colors.black.withOpacity(0.45),
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: GestureDetector(
              onTap: () {}, // absorb taps so they don't dismiss the sheet
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.glowViolet.withOpacity(0.25),
                      blurRadius: 40,
                      spreadRadius: -6,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AssistantCircle(state: assistant.visualState, size: 92),
                    const SizedBox(height: 12),
                    Text(
                      _statusLabel(assistant.visualState),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    if (assistant.responseText.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 8),
                        child: Text(
                          assistant.responseText,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      )
                    else if (assistant.transcript.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          '"${assistant.transcript}"',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontStyle: FontStyle.italic,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    if (assistant.visualState == AssistantVisualState.listening) ...[
                      const SizedBox(height: 8),
                      // Real builds feed this from live on-device speech
                      // recognition; exposed here as a text field so the
                      // UI/UX and AI round-trip can be tested standalone.
                      TextField(
                        controller: _textController,
                        focusNode: _focusNode,
                        autofocus: true,
                        textInputAction: TextInputAction.send,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: const InputDecoration(
                          hintText: 'Type what you\'d say to Weby...',
                          isDense: true,
                        ),
                        onChanged: controllerNotifier.updateTranscript,
                        onSubmitted: (_) => controllerNotifier.submitTranscript(),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: controllerNotifier.submitTranscript,
                          icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                          label: const Text('Send'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
