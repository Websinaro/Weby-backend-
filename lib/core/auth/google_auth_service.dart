import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Thin wrapper around the on-device Google + Firebase auth SDKs.
///
/// Flow: GoogleSignIn produces a Google credential -> that credential signs
/// in to Firebase -> Firebase mints an ID token for the signed-in user.
/// That Firebase ID token (NOT the raw Google idToken) is what gets sent
/// to the backend, which verifies it server-side with firebase-admin.
class GoogleAuthService {
  GoogleAuthService({GoogleSignIn? googleSignIn, FirebaseAuth? firebaseAuth})
      : _googleSignIn = googleSignIn ?? GoogleSignIn(scopes: const ['email', 'profile']),
        _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final GoogleSignIn _googleSignIn;
  final FirebaseAuth _firebaseAuth;

  /// Returns a fresh Firebase ID token after a successful Google sign-in,
  /// or null if the user cancelled the picker.
  Future<String?> signInAndGetIdToken() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null; // user cancelled

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _firebaseAuth.signInWithCredential(credential);
    final idToken = await userCredential.user?.getIdToken();
    return idToken;
  }

  Future<void> signOut() async {
    await Future.wait([
      _googleSignIn.signOut(),
      _firebaseAuth.signOut(),
    ]);
  }
}
