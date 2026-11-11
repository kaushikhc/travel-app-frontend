/// The signed-in traveler as far as auth knows. Profile details come from `/profile/me`.
class UserModel {
  final String username;

  const UserModel({required this.username});
}
