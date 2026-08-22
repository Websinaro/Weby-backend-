import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/native/native_bridge.dart';
import '../../../core/providers.dart';
import '../../history/data/conversation_repository.dart';
import 'assistant_state.dart';

/// Drives the floating Weby orb *when the main app is in the foreground*:
/// opening/closing the overlay, tracking listening/processing/speaking
/// states, and routing a finished transcript to either a local intent
/// (via [NativeBridge], calling straight into Kotlin) or the AI backend.
///
/// When the app is backgrounded, the native OverlayService in
/// android/.../assistant/OverlayService.kt runs this same routing logic
/// independently in Kotlin (see IntentClassifier.kt) so wake-word-
/// triggered commands still work without the main Dart engine alive.
///
/// The live transcript is expected to be fed in via [updateTranscript]
/// as recognized text arrives - in the finished app that stream comes
/// from the Kotlin SpeechRecognizer over a MethodChannel/EventChannel;
/// here it's a clean seam ready for that wiring.
class AssistantController extends StateNotifier<AssistantState> {
  AssistantController(this._conversations, this._nativeBridge) : super(const AssistantState());

  final ConversationRepository _conversations;
  final NativeBridge _nativeBridge;
  Timer? _autoCloseTimer;

  // Mirrors IntentClassifier.kt on the native side so local-vs-AI routing
  // behaves identically whether the app is foregrounded (this path) or
  // the background OverlayService handles it natively without Dart.
  static const _openPrefixes = ['open ', 'launch ', 'start '];
  static const _callPrefixes = ['call my ', 'call ', 'phone my ', 'phone '];

  void openOverlay() {
    _autoCloseTimer?.cancel();
    state = state.copyWith(
      isOverlayVisible: true,
      visualState: AssistantVisualState.listening,
      transcript: '',
      responseText: '',
    );
  }

  void updateTranscript(String text) {
    if (!state.isOverlayVisible) return;
    state = state.copyWith(transcript: text, visualState: AssistantVisualState.listening);
  }

  Future<void> submitTranscript() async {
    final text = state.transcript.trim();
    if (text.isEmpty) {
      closeOverlay();
      return;
    }

    final normalized = text.toLowerCase();
    final openPrefix = _openPrefixes.firstWhere(normalized.startsWith, orElse: () => '');
    final callPrefix = _callPrefixes.firstWhere(normalized.startsWith, orElse: () => '');

    if (openPrefix.isNotEmpty) {
      state = state.copyWith(visualState: AssistantVisualState.executing);
      final target = normalized.substring(openPrefix.length).trim();
      final outcome = await _nativeBridge.openApp(target);
      state = state.copyWith(responseText: _describeOpenOutcome(outcome));
      _scheduleAutoClose();
      return;
    }

    if (callPrefix.isNotEmpty) {
      state = state.copyWith(visualState: AssistantVisualState.executing);
      final relationship = normalized.substring(callPrefix.length).trim();
      final relationships = await _nativeBridge.getRelationships();
      final contact = relationships[relationship];
      if (contact?.phoneNumber == null) {
        state = state.copyWith(
          visualState: AssistantVisualState.error,
          responseText:
              "You haven't set up who your $relationship is yet. Add it in Settings > Contacts.",
        );
      } else {
        await _nativeBridge.callContact(contact!.phoneNumber!);
        state = state.copyWith(responseText: 'Calling ${contact.name}');
      }
      _scheduleAutoClose();
      return;
    }

    state = state.copyWith(visualState: AssistantVisualState.processing);
    try {
      final reply = await _conversations.askAi(text);
      state = state.copyWith(visualState: AssistantVisualState.speaking, responseText: reply);
    } catch (e) {
      state = state.copyWith(
        visualState: AssistantVisualState.error,
        responseText: "Weby couldn't reach the AI assistant. Please try again.",
      );
    }
    _scheduleAutoClose();
  }

  String _describeOpenOutcome(OpenAppOutcome outcome) {
    switch (outcome.status) {
      case 'opened':
        return 'Opening ${outcome.label}';
      case 'ambiguous':
        return 'I found multiple apps matching that: ${outcome.candidates?.join(', ')}';
      default:
        return "Weby couldn't find that app";
    }
  }

  void _scheduleAutoClose() {
    _autoCloseTimer?.cancel();
    _autoCloseTimer = Timer(const Duration(seconds: 4), closeOverlay);
  }

  void closeOverlay() {
    _autoCloseTimer?.cancel();
    state = const AssistantState();
  }

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    super.dispose();
  }
}

final assistantControllerProvider =
    StateNotifierProvider<AssistantController, AssistantState>((ref) {
  return AssistantController(ref.watch(conversationRepositoryProvider), ref.watch(nativeBridgeProvider));
});
