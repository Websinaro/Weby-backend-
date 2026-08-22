import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers.dart';
import '../data/preferences_repository.dart';

/// Loads/holds the user's cloud-synced assistant preferences so the
/// various settings screens can read and patch them without each
/// screen owning its own network round trip.
class PreferencesController extends AsyncNotifier<PreferencesModel> {
  @override
  Future<PreferencesModel> build() {
    return ref.read(preferencesRepositoryProvider).get();
  }

  Future<void> patch(Map<String, dynamic> data) async {
    final repo = ref.read(preferencesRepositoryProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => repo.update(data));
  }
}

final preferencesControllerProvider =
    AsyncNotifierProvider<PreferencesController, PreferencesModel>(PreferencesController.new);
