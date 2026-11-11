class PlaceModel {
  final String id;
  final String name;
  final String country;
  final String category;
  final double rating;
  final String imageUrl;
  final String description;

  const PlaceModel({
    required this.id,
    required this.name,
    required this.country,
    required this.category,
    required this.rating,
    required this.imageUrl,
    required this.description,
  });

  factory PlaceModel.fromJson(Map<String, dynamic> json) {
    return PlaceModel(
      id: json['id'] as String,
      name: json['name'] as String,
      country: json['country'] as String,
      category: json['category'] as String,
      rating: (json['rating'] as num).toDouble(),
      imageUrl: json['imageUrl'] as String,
      description: json['description'] as String,
    );
  }
}
