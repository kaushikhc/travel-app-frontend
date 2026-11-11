import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_app_frontend/core/network/api_client.dart';
import 'package:travel_app_frontend/core/storage/token_storage.dart';
import 'package:travel_app_frontend/features/auth/data/auth_repository.dart';
import 'package:travel_app_frontend/features/auth/data/google_sign_in_gateway.dart';
import 'package:travel_app_frontend/features/auth/presentation/auth_state.dart';

class MemoryTokenStorage implements TokenStorage {
  String? token;
  MemoryTokenStorage([this.token]);
  @override
  Future<String?> read() async => token;
  @override
  Future<void> write(String value) async => token = value;
  @override
  Future<void> clear() async => token = null;
}

class FakeAuthRepository implements AuthRepository {
  SessionCheck check = SessionCheck.valid;
  bool failExchange = false;
  String? lastIdToken;

  @override
  String get googleAuthUrl => 'https://api.example/oauth2/authorization/google';
  @override
  Future<AuthSession> login(String username, String password) async =>
      AuthSession(token: 'jwt-$username', username: username);
  @override
  Future<AuthSession> exchangeGoogleCode(String code) async =>
      failExchange ? throw Exception('Google sign-in expired. Please try again.') : const AuthSession(token: 'jwt-g', username: 'g@example.com');
  @override
  Future<AuthSession> signInWithGoogleIdToken(String idToken) async {
    lastIdToken = idToken;
    return const AuthSession(token: 'jwt-native', username: 'n@example.com');
  }
  @override
  Future<void> register({required String username, required String email, required String password, required String displayName}) async {}
  @override
  Future<SessionCheck> checkSession() async => check;
  @override
  Future<void> logout() async {}
  @override
  Future<AuthSession> chooseUsername({String? username, String? password}) async {
    if (username == 'taken') throw Exception('That username is taken. Please try another.');
    final String name = (username == null || username.isEmpty) ? 'n@example.com' : username;
    return AuthSession(token: 'jwt-$name', username: name);
  }
}

class FakeGoogleGateway implements GoogleSignInGateway {
  String? idToken = 'google-id-token';
  @override
  Future<String?> obtainIdToken() async => idToken;
  @override
  Future<void> signOut() async {}
}

void main() {
  late MemoryTokenStorage storage;
  late FakeAuthRepository repository;
  late FakeGoogleGateway google;
  late ApiClient api;

  ProviderContainer makeContainer() {
    final ProviderContainer c = ProviderContainer(overrides: [
      tokenStorageProvider.overrideWithValue(storage),
      authRepositoryProvider.overrideWithValue(repository),
      googleSignInGatewayProvider.overrideWithValue(google),
      apiClientProvider.overrideWithValue(api),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  Future<AuthState> settled(ProviderContainer c) async {
    c.read(authStateProvider);
    await pumpEventQueue();
    return c.read(authStateProvider);
  }

  setUp(() {
    storage = MemoryTokenStorage();
    repository = FakeAuthRepository();
    google = FakeGoogleGateway();
    api = ApiClient(baseUrl: 'https://api.example/api');
  });

  test('no saved token: signed out', () async {
    expect((await settled(makeContainer())).status, AuthStatus.unauthenticated);
  });

  test('saved valid token: signed in and sent with requests', () async {
    storage.token = 'saved';
    expect((await settled(makeContainer())).status, AuthStatus.authenticated);
    expect(api.hasAuthToken, isTrue);
  });

  test('saved token the server rejects is dropped', () async {
    storage.token = 'stale';
    repository.check = SessionCheck.invalid;
    expect((await settled(makeContainer())).status, AuthStatus.unauthenticated);
    expect(storage.token, isNull);
    expect(api.hasAuthToken, isFalse);
  });

  test('server unreachable keeps the saved session', () async {
    storage.token = 'saved';
    repository.check = SessionCheck.unknown;
    expect((await settled(makeContainer())).status, AuthStatus.authenticated);
  });

  test('password login saves the token', () async {
    final ProviderContainer c = makeContainer();
    await settled(c);
    expect(await c.read(authStateProvider.notifier).login('ana', 'pw'), isTrue);
    expect(c.read(authStateProvider).user?.username, 'ana');
    expect(storage.token, 'jwt-ana');
  });

  test('web code exchange failure shows an error and stays signed out', () async {
    repository.failExchange = true;
    final ProviderContainer c = makeContainer();
    await settled(c);
    expect(await c.read(authStateProvider.notifier).exchangeGoogleCode('old'), isFalse);
    expect(c.read(authStateProvider).status, AuthStatus.error);
    expect(storage.token, isNull);
  });

  test('native Google sends the ID token; cancelling stays signed out', () async {
    final ProviderContainer c = makeContainer();
    await settled(c);
    expect(await c.read(authStateProvider.notifier).signInWithGoogleNative(), isTrue);
    expect(repository.lastIdToken, 'google-id-token');
    expect(storage.token, 'jwt-native');

    await c.read(authStateProvider.notifier).logout();
    google.idToken = null;
    expect(await c.read(authStateProvider.notifier).signInWithGoogleNative(), isFalse);
    expect(c.read(authStateProvider).status, AuthStatus.unauthenticated);
  });

  test('logout clears the token everywhere', () async {
    storage.token = 'saved';
    final ProviderContainer c = makeContainer();
    await settled(c);
    await c.read(authStateProvider.notifier).logout();
    expect(c.read(authStateProvider).status, AuthStatus.unauthenticated);
    expect(storage.token, isNull);
    expect(api.hasAuthToken, isFalse);
  });

  test('choosing a username swaps in the new token and stays signed in', () async {
    final ProviderContainer c = makeContainer();
    await settled(c);
    await c.read(authStateProvider.notifier).signInWithGoogleNative();

    expect(await c.read(authStateProvider.notifier).chooseUsername(username: 'taken'),
        'That username is taken. Please try another.');
    expect(storage.token, 'jwt-native');

    expect(await c.read(authStateProvider.notifier).chooseUsername(username: 'nina_t', password: 'long-enough'), isNull);
    expect(c.read(authStateProvider).status, AuthStatus.authenticated);
    expect(c.read(authStateProvider).user?.username, 'nina_t');
    expect(storage.token, 'jwt-nina_t');
  });
}
