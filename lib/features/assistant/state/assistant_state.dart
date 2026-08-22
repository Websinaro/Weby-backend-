/// Every visual/behavioral mode the floating Weby orb can be in.
/// Mirrors the states called out in the product spec: idle, listening,
/// processing, speaking, executing, error.
enum AssistantVisualState { idle, listening, processing, speaking, executing, error }

class AssistantState {
  const AssistantState({
    this.visualState = AssistantVisualState.idle,
    this.transcript = '',
    this.responseText = '',
    this.isOverlayVisible = false,
  });

  final AssistantVisualState visualState;
  final String transcript;
  final String responseText;
  final bool isOverlayVisible;

  AssistantState copyWith({
    AssistantVisualState? visualState,
    String? transcript,
    String? responseText,
    bool? isOverlayVisible,
  }) {
    return AssistantState(
      visualState: visualState ?? this.visualState,
      transcript: transcript ?? this.transcript,
      responseText: responseText ?? this.responseText,
      isOverlayVisible: isOverlayVisible ?? this.isOverlayVisible,
    );
  }
}
