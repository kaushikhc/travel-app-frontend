import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_app_frontend/core/network/api_client.dart';
import 'package:travel_app_frontend/core/time/api_time.dart';
import 'package:travel_app_frontend/features/auth/domain/user_model.dart';
import 'package:travel_app_frontend/features/auth/presentation/auth_state.dart';
import 'package:travel_app_frontend/features/profile/data/profile_repository.dart';
import 'package:travel_app_frontend/features/profile/domain/profile_model.dart';
import 'package:travel_app_frontend/features/profile/presentation/profile_state.dart';

class SignedInAuth extends AuthNotifier {
  @override
  AuthState build() => const AuthState.authenticated(UserModel(username: 'ana'));
}

class FakeProfileRepository extends ProfileRepository {
  FakeProfileRepository(this.serverZone) : super(ApiClient(baseUrl: 'https://api.example/api'));
  String serverZone;
  final List<String> sent = <String>[];

  ProfileModel get _profile => ProfileModel(
      travelerId: 1, username: 'ana', displayName: 'Ana', email: 'a@example.com', timeZone: serverZone);

  @override
  Future<ProfileModel> fetchMyProfile() async => _profile;

  @override
  Future<ProfileModel> updateTimeZone(String timeZone) async {
    sent.add(timeZone);
    serverZone = timeZone;
    return _profile;
  }
}

class FixedZone implements DeviceTimeZone {
  const FixedZone(this.zone);
  final String? zone;
  @override
  Future<String?> current() async => zone;
}

Future<ProviderContainer> load(FakeProfileRepository repo, String? deviceZone) async {
  final ProviderContainer c = ProviderContainer(overrides: [
    authStateProvider.overrideWith(SignedInAuth.new),
    profileRepositoryProvider.overrideWithValue(repo),
    deviceTimeZoneProvider.overrideWithValue(FixedZone(deviceZone)),
  ]);
  addTearDown(c.dispose);
  c.read(profileNotifierProvider);
  await pumpEventQueue();
  return c;
}

void main() {
  test('sends the device zone when the profile still has another', () async {
    final FakeProfileRepository repo = FakeProfileRepository('UTC');
    final ProviderContainer c = await load(repo, 'Asia/Kolkata');
    expect(repo.sent, <String>['Asia/Kolkata']);
    expect(c.read(profileNotifierProvider).profile?.timeZone, 'Asia/Kolkata');
  });

  test('sends nothing when the zones match or the device zone is unknown', () async {
    final FakeProfileRepository same = FakeProfileRepository('Asia/Kolkata');
    await load(same, 'Asia/Kolkata');
    expect(same.sent, isEmpty);

    final FakeProfileRepository unknown = FakeProfileRepository('UTC');
    await load(unknown, null);
    expect(unknown.sent, isEmpty);
  });
}
