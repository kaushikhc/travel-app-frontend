import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Native Google sign-in (Android). The ID token is requested for the backend's web client id,
/// passed at build time with `--dart-define=GOOGLE_SERVER_CLIENT_ID=...`.
/// The web build does not use this; it signs in through the backend redirect.
abstract class GoogleSignInGateway {
  /// Returns a Google ID token, or null when the user cancels.
  Future<String?> obtainIdToken();
  Future<void> signOut();
}

class NativeGoogleSignInGateway implements GoogleSignInGateway {
  static const String serverClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await GoogleSignIn.instance.initialize(
      serverClientId: serverClientId.isEmpty ? null : serverClientId,
    );
    _initialized = true;
  }

  @override
  Future<String?> obtainIdToken() async {
    await _ensureInitialized();
    try {
      final GoogleSignInAccount account = await GoogleSignIn.instance.authenticate();
      return account.authentication.idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    if (kIsWeb || !_initialized) return;
    await GoogleSignIn.instance.signOut();
  }
}

final googleSignInGatewayProvider = Provider<GoogleSignInGateway>((Ref ref) => NativeGoogleSignInGateway());
