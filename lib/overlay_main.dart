import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/network/api_client.dart';
import 'core/storage/secure_storage_service.dart';
import 'core/theme/app_theme.dart';
import 'features/assistant/presentation/assistant_circle.dart';
import 'features/assistant/state/assistant_state.dart';
import 'features/history/data/conversation_repository.dart';

/// Separate Flutter entrypoint that runs INSIDE the native floating
/// overlay window (see OverlayService.kt), completely independent of the
/// main app's engine/process state. It has no Riverpod ProviderScope of
/// its own by design - it's a small, self-contained surface wired only
/// to native events over the "com.weby/overlay" MethodChannel.
///
/// flutter_secure_storage reads the same OS-level encrypted store
/// regardless of which engine/isolate calls it, so this entrypoint can
/// still make authenticated backend calls even though the main app
/// isn't running.
@pragma('vm:entry-point')
void overlayMain() {
  runApp(const _OverlayApp());
}

class _OverlayApp extends StatelessWidget {
  const _OverlayApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const Material(
        type: MaterialType.transparency,
        child: _OverlaySurface(),
      ),
    );
  }
}

class _OverlaySurface extends StatefulWidget {
  const _OverlaySurface();

  @override
  State<_OverlaySurface> createState() => _OverlaySurfaceState();
}

class _OverlaySurfaceState extends State<_OverlaySurface> {
  static const _channel = MethodChannel('com.weby/overlay');

  late final SecureStorageService _secureStorage = SecureStorageService();
  late final ApiClient _apiClient = ApiClient(_secureStorage);
  late final ConversationRepository _conversations = ConversationRepository(_apiClient);

  AssistantVisualState _visualState = AssistantVisualState.listening;
  String _transcript = '';
  String _responseText = '';

  @override
  void initState() {
    super.initState();
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onWakeWordDetected':
        setState(() {
          _visualState = AssistantVisualState.listening;
          _transcript = '';
          _responseText = '';
        });
        break;

      case 'onPartialTranscript':
      case 'onFinalTranscript':
        setState(() => _transcript = call.arguments['text'] as String? ?? '');
        break;

      case 'onLocalExecutionResult':
        setState(() {
          _visualState = AssistantVisualState.executing;
          _responseText = call.arguments['message'] as String? ?? '';
        });
        await _speakThenClose(_responseText);
        break;

      case 'onListeningError':
        setState(() {
          _visualState = AssistantVisualState.error;
          _responseText = call.arguments['message'] as String? ?? 'Something went wrong';
        });
        await _closeAfterDelay();
        break;

      case 'onAiPromptRequested':
        await _handleAiPrompt(call.arguments['prompt'] as String? ?? '');
        break;
    }
    return null;
  }

  Future<void> _handleAiPrompt(String prompt) async {
    setState(() => _visualState = AssistantVisualState.processing);
    try {
      final reply = await _conversations.askAi(prompt);
      setState(() {
        _visualState = AssistantVisualState.speaking;
        _responseText = reply;
      });
      await _speakThenClose(reply);
    } catch (_) {
      setState(() {
        _visualState = AssistantVisualState.error;
        _responseText = "Weby couldn't reach the AI assistant.";
      });
      await _closeAfterDelay();
    }
  }

  Future<void> _speakThenClose(String text) async {
    await _channel.invokeMethod('speak', {'text': text});
    // Native calls back with onSpeakingDone once TTS finishes; as a
    // safety net in case that ever doesn't fire, also close after a delay.
    await _closeAfterDelay(seconds: 5);
  }

  Future<void> _closeAfterDelay({int seconds = 3}) async {
    await Future<void>.delayed(Duration(seconds: seconds));
    if (!mounted) return;
    await _channel.invokeMethod('closeOverlay');
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AssistantCircle(state: _visualState, size: 92),
            const SizedBox(height: 12),
            if (_responseText.isNotEmpty)
              Text(
                _responseText,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textPrimary),
              )
            else if (_transcript.isNotEmpty)
              Text(
                '"$_transcript"',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
