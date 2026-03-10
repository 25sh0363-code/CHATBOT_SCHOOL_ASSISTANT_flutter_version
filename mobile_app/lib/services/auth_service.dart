import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService();

  final ValueNotifier<bool> isSignedIn = ValueNotifier<bool>(false);
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  GoogleSignInAccount? _account;

  bool get isGoogleSignInSupported {
    return ![
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
    ].contains(defaultTargetPlatform);
  }

  String get displayName => _account?.displayName ?? 'Student';
  String get email => _account?.email ?? '';

  Future<void> signInWithGoogle() async {
    if (!isGoogleSignInSupported) {
      isSignedIn.value = false;
      return;
    }

    try {
      _account = await _googleSignIn.signIn();
      isSignedIn.value = _account != null;
    } catch (_) {
      isSignedIn.value = false;
    }
  }

  void continueAsGuest() {
    _account = null;
    isSignedIn.value = true;
  }

  Future<void> signOut() async {
    if (isGoogleSignInSupported) {
      await _googleSignIn.signOut();
    }
    _account = null;
    isSignedIn.value = false;
  }
}
