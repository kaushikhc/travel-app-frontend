import '../../../core/time/api_time.dart';
import 'api_date.dart';

class ProfileModel {
  final int travelerId;
  final String username;
  final String displayName;
  final String email;
  final String? bio;
  final int? homeCountryId;

  /// A link to show the photo. For an uploaded photo it is short-lived (about an hour);
  /// reload the profile for a fresh one.
  final String? photoUrl;

  /// The uploaded photo, or null when there is none or only an external link.
  final int? photoMediaId;

  /// Worked out from [birthday] by the server when a birthday is set.
  final int? age;

  /// A calendar date (local midnight), no time zone.
  final DateTime? birthday;

  /// UTC.
  final DateTime? createdAt;

  /// IANA zone id stored on the server (default `UTC`).
  final String timeZone;
  /// False right after a first Google sign-in, until the traveler picks a username or skips.
  final bool usernameChosen;

  const ProfileModel({
    required this.travelerId,
    required this.username,
    required this.displayName,
    required this.email,
    this.bio,
    this.homeCountryId,
    this.photoUrl,
    this.photoMediaId,
    this.age,
    this.birthday,
    this.createdAt,
    this.timeZone = 'UTC',
    this.usernameChosen = true,
  });

  /// Returns true when all mandatory on-boarding fields are filled.
  bool get isProfileComplete =>
      displayName.trim().isNotEmpty && (bio?.trim().isNotEmpty ?? false) && homeCountryId != null;

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      travelerId: json['travelerId'] as int,
      username: json['username'] as String,
      displayName: json['displayName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      bio: json['bio'] as String?,
      homeCountryId: json['homeCountryId'] as int?,
      photoUrl: json['photoUrl'] as String?,
      photoMediaId: json['photoMediaId'] as int?,
      age: json['age'] as int?,
      birthday: ApiDate.parse(json['birthday'] as String?),
      createdAt: ApiTime.parseUtc(json['createdAt'] as String?),
      timeZone: json['timeZone'] as String? ?? 'UTC',
      usernameChosen: json['usernameChosen'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'travelerId': travelerId,
      'username': username,
      'displayName': displayName,
      'email': email,
      'bio': bio,
      'homeCountryId': homeCountryId,
      'photoUrl': photoUrl,
      'photoMediaId': photoMediaId,
      'age': age,
      'birthday': birthday == null ? null : ApiDate.format(birthday!),
      'createdAt': createdAt?.toIso8601String(),
      'timeZone': timeZone,
    };
  }

  ProfileModel copyWith({
    int? travelerId,
    String? username,
    String? displayName,
    String? email,
    String? bio,
    int? homeCountryId,
    String? photoUrl,
    int? photoMediaId,
    int? age,
    DateTime? birthday,
    DateTime? createdAt,
    String? timeZone,
  }) {
    return ProfileModel(
      travelerId: travelerId ?? this.travelerId,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      bio: bio ?? this.bio,
      homeCountryId: homeCountryId ?? this.homeCountryId,
      photoUrl: photoUrl ?? this.photoUrl,
      photoMediaId: photoMediaId ?? this.photoMediaId,
      age: age ?? this.age,
      birthday: birthday ?? this.birthday,
      createdAt: createdAt ?? this.createdAt,
      timeZone: timeZone ?? this.timeZone,
    );
  }
}
