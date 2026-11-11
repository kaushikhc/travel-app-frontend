import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../data/profile_repository.dart';
import '../domain/profile_model.dart';

class ProfileState {
  final bool isLoading;
  final ProfileModel? profile;
  final String? errorMessage;

  const ProfileState({
    required this.isLoading,
    this.profile,
    this.errorMessage,
  });

  factory ProfileState.idle() => const ProfileState(isLoading: false);
  factory ProfileState.initial() => const ProfileState(isLoading: true);
  factory ProfileState.loading(ProfileModel? current) => ProfileState(isLoading: true, profile: current);
  factory ProfileState.success(ProfileModel profile) => ProfileState(isLoading: false, profile: profile);
  factory ProfileState.error(String message, [ProfileModel? current]) =>
      ProfileState(isLoading: false, errorMessage: message, profile: current);

  /// True when profile has been loaded and mandatory fields are incomplete.
  bool get needsSetup => !isLoading && profile != null && !profile!.isProfileComplete;
}

class ProfileNotifier extends Notifier<ProfileState> {
  late final ProfileRepository _repository;
  late final ApiClient _apiClient;

  @override
  ProfileState build() {
    _repository = ref.watch(profileRepositoryProvider);
    _apiClient = ref.watch(apiClientProvider);
    // Only auto-load if a token is already present (e.g. on page refresh with stored token).
    // For OAuth and credentials login, loadProfile() is called explicitly from the router.
    if (_apiClient.hasAuthToken) {
      loadProfile();
      return ProfileState.initial();
    }
    return ProfileState.idle();
  }

  Future<void> loadProfile() async {
    state = ProfileState.loading(state.profile);
    try {
      final profile = await _repository.fetchMyProfile();
      state = ProfileState.success(profile);
    } catch (e) {
      state = ProfileState.error(e.toString().replaceAll('Exception: ', ''), state.profile);
    }
  }

  /// Loads the profile only if not already loaded. Safe to call from the router redirect.
  Future<void> loadProfileOnce() async {
    if (!state.isLoading && state.profile != null) return;
    await loadProfile();
  }

  /// Reset to idle (called on logout).
  void reset() {
    state = ProfileState.idle();
  }

  Future<bool> updateProfile({
    required String displayName,
    String? bio,
    int? homeCountryId,
    String? photoUrl,
    int? age,
    String? birthday,
  }) async {
    final currentProfile = state.profile;
    state = ProfileState.loading(currentProfile);
    try {
      final updated = await _repository.updateProfile(
        displayName: displayName,
        bio: bio,
        homeCountryId: homeCountryId,
        photoUrl: photoUrl,
        age: age,
        birthday: birthday,
      );
      state = ProfileState.success(updated);
      return true;
    } catch (e) {
      state = ProfileState.error(e.toString().replaceAll('Exception: ', ''), currentProfile);
      return false;
    }
  }
}

final profileNotifierProvider = NotifierProvider<ProfileNotifier, ProfileState>(ProfileNotifier.new);
