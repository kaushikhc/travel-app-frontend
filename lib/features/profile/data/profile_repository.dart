import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../domain/api_date.dart';
import '../domain/profile_model.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ProfileRepository(apiClient);
});

class ProfileRepository {
  final ApiClient _apiClient;

  ProfileRepository(this._apiClient);

  Future<ProfileModel> fetchMyProfile() async {
    final response = await _apiClient.get('/profile/me');
    if (response.statusCode == 200) {
      return ProfileModel.fromJson(response.data as Map<String, dynamic>);
    } else {
      throw Exception('Failed to fetch profile: ${response.statusMessage}');
    }
  }

  /// PUT /api/profile/me. Null fields are left as they are on the server.
  /// [photoMediaId] is an uploaded photo (see MediaRepository.uploadPhoto);
  Future<ProfileModel> updateProfile({
    required String displayName,
    String? bio,
    int? homeCountryId,
    int? photoMediaId,
    DateTime? birthday,
  }) async {
    final response = await _apiClient.put(
      '/profile/me',
      data: updateBody(
        displayName: displayName,
        bio: bio,
        homeCountryId: homeCountryId,
        photoMediaId: photoMediaId,
        birthday: birthday,
      ),
    );
    if (response.statusCode == 200) {
      return ProfileModel.fromJson(response.data as Map<String, dynamic>);
    } else {
      throw Exception('Failed to update profile: ${response.statusMessage}');
    }
  }

  static Map<String, dynamic> updateBody({
    required String displayName,
    String? bio,
    int? homeCountryId,
    int? photoMediaId,
    DateTime? birthday,
  }) {
    return <String, dynamic>{
      'displayName': displayName,
      'bio': bio,
      'homeCountryId': homeCountryId,
      'photoMediaId': ?photoMediaId,
      'birthday': birthday == null ? null : ApiDate.format(birthday),
    };
  }

  /// PUT /api/profile/me with only the time zone (the server ignores missing fields).
  Future<ProfileModel> updateTimeZone(String timeZone) async {
    final response = await _apiClient.put('/profile/me', data: <String, String>{'timeZone': timeZone});
    return ProfileModel.fromJson(response.data as Map<String, dynamic>);
  }
}
