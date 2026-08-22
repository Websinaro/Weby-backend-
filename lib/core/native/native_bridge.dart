import 'package:flutter/services.dart';

/// Typed wrapper around the "com.weby/bridge" MethodChannel implemented
/// natively in MainActivity.kt. This is the ONLY place in the Dart
/// codebase that should reference platform-channel method names, so a
/// rename on the Kotlin side only ever needs updating in one spot here.
class AppInfo {
  AppInfo({required this.label, required this.packageName});
  final String label;
  final String packageName;

  factory AppInfo.fromMap(Map map) =>
      AppInfo(label: map['label'] as String, packageName: map['packageName'] as String);
}

class DeviceContact {
  DeviceContact({required this.id, required this.name, this.phoneNumber});
  final String id;
  final String name;
  final String? phoneNumber;

  factory DeviceContact.fromMap(Map map) => DeviceContact(
        id: map['id'] as String,
        name: map['name'] as String,
        phoneNumber: map['phoneNumber'] as String?,
      );
}

class OpenAppOutcome {
  OpenAppOutcome({required this.status, this.label, this.candidates});
  final String status; // opened | ambiguous | not_found
  final String? label;
  final List<String>? candidates;
}

class PermissionStatus {
  PermissionStatus({
    required this.microphone,
    required this.contacts,
    required this.callPhone,
    required this.overlay,
    required this.notifications,
    required this.batteryUnrestricted,
  });
  final bool microphone;
  final bool contacts;
  final bool callPhone;
  final bool overlay;
  final bool notifications;
  final bool batteryUnrestricted;

  bool get allCoreGranted => microphone && contacts && overlay;

  factory PermissionStatus.fromMap(Map map) => PermissionStatus(
        microphone: map['microphone'] as bool? ?? false,
        contacts: map['contacts'] as bool? ?? false,
        callPhone: map['callPhone'] as bool? ?? false,
        overlay: map['overlay'] as bool? ?? false,
        notifications: map['notifications'] as bool? ?? false,
        batteryUnrestricted: map['batteryUnrestricted'] as bool? ?? false,
      );
}

class NativeBridge {
  NativeBridge() : _channel = const MethodChannel('com.weby/bridge');

  final MethodChannel _channel;

  Future<List<AppInfo>> getAvailableApps() async {
    final result = await _channel.invokeMethod<List<dynamic>>('getAvailableApps');
    return (result ?? []).map((e) => AppInfo.fromMap(e as Map)).toList();
  }

  Future<OpenAppOutcome> openApp(String target) async {
    final result = await _channel.invokeMapMethod<String, dynamic>('openApp', {'target': target});
    return OpenAppOutcome(
      status: result?['status'] as String? ?? 'not_found',
      label: result?['label'] as String?,
      candidates: (result?['candidates'] as List?)?.cast<String>(),
    );
  }

  Future<List<DeviceContact>> getContacts() async {
    final result = await _channel.invokeMethod<List<dynamic>>('getContacts');
    return (result ?? []).map((e) => DeviceContact.fromMap(e as Map)).toList();
  }

  Future<String> callContact(String phoneNumber) async {
    final result =
        await _channel.invokeMapMethod<String, dynamic>('callContact', {'phoneNumber': phoneNumber});
    return result?['status'] as String? ?? 'permission_denied';
  }

  Future<void> saveRelationship(String relationship, DeviceContact contact) {
    return _channel.invokeMethod('saveRelationship', {
      'relationship': relationship,
      'contactId': contact.id,
      'name': contact.name,
      'phoneNumber': contact.phoneNumber,
    });
  }

  Future<Map<String, DeviceContact>> getRelationships() async {
    final result = await _channel.invokeMapMethod<String, dynamic>('getRelationships');
    if (result == null) return {};
    return result.map((key, value) => MapEntry(key, DeviceContact.fromMap(value as Map)));
  }

  Future<void> removeRelationship(String relationship) {
    return _channel.invokeMethod('removeRelationship', {'relationship': relationship});
  }

  Future<PermissionStatus> checkPermissions() async {
    final result = await _channel.invokeMapMethod<String, dynamic>('checkPermissions');
    return PermissionStatus.fromMap(result ?? {});
  }

  Future<void> requestPermissions() => _channel.invokeMethod('requestPermissions');

  Future<void> requestOverlayPermission() => _channel.invokeMethod('requestOverlayPermission');

  /// Opens the system "exempt from battery optimization" dialog. Only
  /// call this from an explicit user action (e.g. a settings toggle) -
  /// never automatically, since declining is a completely valid choice
  /// and the OS discourages apps from nagging about it.
  Future<void> requestIgnoreBatteryOptimizations() =>
      _channel.invokeMethod('requestIgnoreBatteryOptimizations');

  Future<void> startAssistant({required String wakeWord}) {
    return _channel.invokeMethod('startAssistant', {'wakeWord': wakeWord});
  }

  Future<void> stopAssistant() => _channel.invokeMethod('stopAssistant');
}
