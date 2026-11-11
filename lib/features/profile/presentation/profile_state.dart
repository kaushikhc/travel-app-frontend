import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/time/api_time.dart';
import '../../auth/presentation/auth_state.dart';
import '../data/profile_repository.dart';
import '../domain/profile_model.dart';

class ProfileState {
  final bool isLoading;
  final ProfileModel? profile;
  final String? errorMessage;

  const ProfileState({required this.isLoading, this.profile, this.errorMessage});

  factory ProfileState.idle() => const ProfileState(isLoading: false);
  factory ProfileState.initial() => const ProfileState(isLoading: true);
  factory ProfileState.loading(ProfileModel? current) => ProfileState(isLoading: true, profile: current);
  factory ProfileState.success(ProfileModel profile) => ProfileState(isLoading: false, profile: profile);
  factory ProfileState.error(String message, [ProfileModel? current]) =>
      ProfileState(isLoading: false, errorMessage: message, profile: current);

  /// True when profile has been loaded and mandatory fields are incomplete.
  bool get needsSetup => !isLoading && profile != null && !profile!.isProfileComplete;
}

/// Loads the profile whenever a session starts and resets when it ends (it rebuilds on sign-in/out).
class ProfileNotifier extends Notifier<ProfileState> {
  ProfileRepository get _repository => ref.read(profileRepositoryProvider);

  @override
  ProfileState build() {
    final bool signedIn = ref.watch(authStateProvider.select((AuthState s) => s.isAuthenticated));
    if (!signedIn) return ProfileState.idle();
    Future<void>.microtask(loadProfile);
    return ProfileState.initial();
  }

  Future<void> loadProfile() async {
    if (!ref.mounted) return;
    state = ProfileState.loading(state.profile);
    try {
      final profile = await _repository.fetchMyProfile();
      if (ref.mounted) state = ProfileState.success(profile);
      await _syncTimeZone(profile);
    } catch (e) {
      if (ref.mounted) state = ProfileState.error(e.toString().replaceAll('Exception: ', ''), state.profile);
    }
  }

  /// Sends the device time zone when it differs from the profile's. Best effort: a failure
  /// leaves the profile as it is and is retried on the next load.
  Future<void> _syncTimeZone(ProfileModel profile) async {
    final String? device = await ref.read(deviceTimeZoneProvider).current();
    if (device == null || device.isEmpty || device == profile.timeZone || !ref.mounted) return;
    try {
      final ProfileModel updated = await _repository.updateTimeZone(device);
      if (ref.mounted && !state.isLoading) state = ProfileState.success(updated);
    } catch (_) {}
  }

  Future<bool> updateProfile({
    required String displayName,
    String? bio,
    int? homeCountryId,
    int? photoMediaId,
    DateTime? birthday,
  }) async {
    final currentProfile = state.profile;
    state = ProfileState.loading(currentProfile);
    try {
      final updated = await _repository.updateProfile(
        displayName: displayName,
        bio: bio,
        homeCountryId: homeCountryId,
        photoMediaId: photoMediaId,
        birthday: birthday,
      );
      if (ref.mounted) state = ProfileState.success(updated);
      return true;
    } catch (e) {
      if (ref.mounted) state = ProfileState.error(e.toString().replaceAll('Exception: ', ''), currentProfile);
      return false;
    }
  }
}

final profileNotifierProvider = NotifierProvider<ProfileNotifier, ProfileState>(ProfileNotifier.new);
