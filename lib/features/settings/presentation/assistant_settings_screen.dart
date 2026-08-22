import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../preferences/state/preferences_controller.dart';

class AssistantSettingsScreen extends ConsumerStatefulWidget {
  const AssistantSettingsScreen({super.key});

  @override
  ConsumerState<AssistantSettingsScreen> createState() => _AssistantSettingsScreenState();
}

class _AssistantSettingsScreenState extends ConsumerState<AssistantSettingsScreen> {
  final _assistantNameController = TextEditingController();
  final _wakeWordController = TextEditingController();
  bool _initialized = false;
  bool _assistantRunning = false;
  bool _batteryUnrestricted = false;

  @override
  void initState() {
    super.initState();
    _loadPermissionStatus();
  }

  Future<void> _loadPermissionStatus() async {
    final status = await ref.read(nativeBridgeProvider).checkPermissions();
    if (!mounted) return;
    setState(() => _batteryUnrestricted = status.batteryUnrestricted);
  }

  Future<void> _requestBatteryExemption() async {
    await ref.read(nativeBridgeProvider).requestIgnoreBatteryOptimizations();
    // The system dialog result doesn't come back synchronously - re-check
    // shortly after the user returns to the app.
    await Future<void>.delayed(const Duration(milliseconds: 800));
    await _loadPermissionStatus();
  }

  Future<void> _toggleAssistantRunning(bool enabled, String wakeWord) async {
    final bridge = ref.read(nativeBridgeProvider);
    if (enabled) {
      final permissions = await bridge.checkPermissions();
      if (!permissions.overlay) {
        await bridge.requestOverlayPermission();
      }
      if (!permissions.microphone || !permissions.contacts) {
        await bridge.requestPermissions();
      }
      await bridge.startAssistant(wakeWord: wakeWord);
    } else {
      await bridge.stopAssistant();
    }
    setState(() => _assistantRunning = enabled);
  }

  @override
  void dispose() {
    _assistantNameController.dispose();
    _wakeWordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final prefsAsync = ref.watch(preferencesControllerProvider);
    final controller = ref.read(preferencesControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Assistant')),
      body: prefsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Could not load preferences: $err')),
        data: (prefs) {
          if (!_initialized) {
            _assistantNameController.text = prefs.assistantName;
            _wakeWordController.text = prefs.wakeWord;
            _initialized = true;
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                child: SwitchListTile(
                  title: const Text('Assistant enabled'),
                  subtitle: Text(
                    _assistantRunning
                        ? 'Listening in the background for "${prefs.wakeWord}"'
                        : 'Weby only responds when you open the app',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                  ),
                  value: _assistantRunning,
                  onChanged: (v) => _toggleAssistantRunning(v, prefs.wakeWord),
                ),
              ),
              if (_assistantRunning && !_batteryUnrestricted) ...[
                const SizedBox(height: 10),
                Card(
                  color: AppColors.surfaceElevated,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.battery_alert_outlined, color: AppColors.warning, size: 20),
                            SizedBox(width: 8),
                            Text('Background listening may be delayed', style: TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Weby already keeps mic use minimal while on standby (no cloud '
                          'speech calls until it hears real speech). Some phone makers still '
                          'pause background apps aggressively to save battery, which can delay '
                          'wake-word response when the app is fully closed. Exempting Weby from '
                          'battery optimization keeps it responsive - this is optional and you '
                          'can undo it anytime in Android Settings.',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.4),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _requestBatteryExemption,
                          child: const Text('Exempt Weby from battery optimization'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              const Text('Assistant name', style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              TextField(
                controller: _assistantNameController,
                decoration: const InputDecoration(hintText: 'Weby'),
                onSubmitted: (v) => controller.patch({'assistantName': v}),
              ),
              const SizedBox(height: 20),
              const Text('Wake word', style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              TextField(
                controller: _wakeWordController,
                decoration: const InputDecoration(hintText: 'Weby'),
                onSubmitted: (v) => controller.patch({'wakeWord': v}),
              ),
              const SizedBox(height: 8),
              const Text(
                'Wake-word detection runs locally on-device and never streams '
                'raw audio to the cloud just to listen for this word.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
              ),
              const SizedBox(height: 24),
              Card(
                child: SwitchListTile(
                  title: const Text('Voice verification'),
                  subtitle: const Text(
                    'Confirms it\'s likely you speaking. Not a substitute for device authentication.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                  ),
                  value: prefs.voiceVerificationEnabled,
                  onChanged: (v) => controller.patch({'voiceVerificationEnabled': v}),
                ),
              ),
              const SizedBox(height: 16),
              const Text('AI provider', style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    RadioListTile<String>(
                      title: const Text('Gemini'),
                      value: 'gemini',
                      groupValue: prefs.aiProvider,
                      onChanged: (v) => controller.patch({'aiProvider': v}),
                    ),
                    const Divider(height: 1),
                    RadioListTile<String>(
                      title: const Text('Hugging Face'),
                      value: 'huggingface',
                      groupValue: prefs.aiProvider,
                      onChanged: (v) => controller.patch({'aiProvider': v}),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
