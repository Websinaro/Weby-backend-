import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A tiny, dependency-free pub/sub used only to break the circular
/// reference between [apiClientProvider] and [authControllerProvider].
///
/// ApiClient cannot depend on AuthController directly: AuthController's
/// own dependency chain (authRepositoryProvider -> apiClientProvider)
/// runs straight back through ApiClient. So instead ApiClient just bumps
/// this counter when a session expires, and AuthController (which is
/// free to depend on this, since this depends on nothing) listens for it.
class SessionExpiredNotifier extends StateNotifier<int> {
  SessionExpiredNotifier() : super(0);

  void notify() => state++;
}

final sessionExpiredProvider = StateNotifierProvider<SessionExpiredNotifier, int>((ref) {
  return SessionExpiredNotifier();
});
