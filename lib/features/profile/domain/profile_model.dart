class ProfileModel {
  final int travelerId;
  final String username;
  final String displayName;
  final String email;
  final String? bio;
  final int? homeCountryId;
  final String? photoUrl;
  final int? age;
  final String? birthday;
  final DateTime? createdAt;

  const ProfileModel({
    required this.travelerId,
    required this.username,
    required this.displayName,
    required this.email,
    this.bio,
    this.homeCountryId,
    this.photoUrl,
    this.age,
    this.birthday,
    this.createdAt,
  });

  /// Returns true when all mandatory on-boarding fields are filled.
  bool get isProfileComplete =>
      displayName.trim().isNotEmpty &&
      (bio?.trim().isNotEmpty ?? false) &&
      homeCountryId != null;

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      travelerId: json['travelerId'] as int,
      username: json['username'] as String,
      displayName: json['displayName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      bio: json['bio'] as String?,
      homeCountryId: json['homeCountryId'] as int?,
      photoUrl: json['photoUrl'] as String?,
      age: json['age'] as int?,
      birthday: json['birthday'] as String?,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'] as String) : null,
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
      'age': age,
      'birthday': birthday,
      'createdAt': createdAt?.toIso8601String(),
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
    int? age,
    String? birthday,
    DateTime? createdAt,
  }) {
    return ProfileModel(
      travelerId: travelerId ?? this.travelerId,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      bio: bio ?? this.bio,
      homeCountryId: homeCountryId ?? this.homeCountryId,
      photoUrl: photoUrl ?? this.photoUrl,
      age: age ?? this.age,
      birthday: birthday ?? this.birthday,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
