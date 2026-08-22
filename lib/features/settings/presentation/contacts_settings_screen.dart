import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/native/native_bridge.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';

/// "Who is your mom / dad / bro?" setup screen (spec section 26-27).
/// Reads the device contact list locally via NativeBridge and stores the
/// relationship -> contact mapping natively (RelationshipStore.kt) -
/// nothing here ever reaches the Weby backend.
class ContactsSettingsScreen extends ConsumerStatefulWidget {
  const ContactsSettingsScreen({super.key});

  @override
  ConsumerState<ContactsSettingsScreen> createState() => _ContactsSettingsScreenState();
}

class _ContactsSettingsScreenState extends ConsumerState<ContactsSettingsScreen> {
  static const _suggestedRelationships = ['mom', 'dad', 'bro', 'sister', 'best friend', 'partner'];

  PermissionStatus? _permissions;
  Map<String, DeviceContact> _relationships = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bridge = ref.read(nativeBridgeProvider);
    final permissions = await bridge.checkPermissions();
    final relationships = permissions.contacts ? await bridge.getRelationships() : <String, DeviceContact>{};
    if (!mounted) return;
    setState(() {
      _permissions = permissions;
      _relationships = relationships;
      _loading = false;
    });
  }

  Future<void> _requestPermission() async {
    await ref.read(nativeBridgeProvider).requestPermissions();
    // Give the OS permission dialog a moment before re-checking status.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    await _load();
  }

  Future<void> _pickContactFor(String relationship) async {
    final bridge = ref.read(nativeBridgeProvider);
    final contacts = await bridge.getContacts();
    if (!mounted) return;

    final selected = await showModalBottomSheet<DeviceContact>(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      isScrollControlled: true,
      builder: (context) => _ContactPickerSheet(contacts: contacts),
    );

    if (selected != null) {
      await bridge.saveRelationship(relationship, selected);
      await _load();
    }
  }

  Future<void> _removeRelationship(String relationship) async {
    await ref.read(nativeBridgeProvider).removeRelationship(relationship);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contacts')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : (_permissions?.contacts != true)
              ? _permissionPrompt()
              : _relationshipList(),
    );
  }

  Widget _permissionPrompt() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.contacts_outlined, size: 48, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          const Text(
            'Weby needs access to your contacts to set up commands like '
            '"call my bro". Your contacts are read locally and never leave your device.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: _requestPermission, child: const Text('Grant contacts access')),
        ],
      ),
    );
  }

  Widget _relationshipList() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: _suggestedRelationships.map((relationship) {
        final contact = _relationships[relationship];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.surface,
              child: Text(relationship[0].toUpperCase()),
            ),
            title: Text('Who is your $relationship?'),
            subtitle: Text(
              contact?.name ?? 'Not set',
              style: TextStyle(color: contact != null ? AppColors.textPrimary : AppColors.textMuted),
            ),
            trailing: contact != null
                ? IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textMuted),
                    onPressed: () => _removeRelationship(relationship),
                  )
                : const Icon(Icons.chevron_right, color: AppColors.textMuted),
            onTap: () => _pickContactFor(relationship),
          ),
        );
      }).toList(),
    );
  }
}

class _ContactPickerSheet extends StatelessWidget {
  const _ContactPickerSheet({required this.contacts});
  final List<DeviceContact> contacts;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      expand: false,
      builder: (context, scrollController) => ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: contacts.length,
        itemBuilder: (context, i) {
          final c = contacts[i];
          return ListTile(
            title: Text(c.name),
            subtitle: Text(c.phoneNumber ?? '', style: const TextStyle(color: AppColors.textSecondary)),
            onTap: () => Navigator.of(context).pop(c),
          );
        },
      ),
    );
  }
}
