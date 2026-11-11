class TripModel {
  final String id;
  final String title;
  final String destination;
  final DateTime startDate;
  final DateTime endDate;
  final String coverImageUrl;
  final int placesCount;
  final int memoriesCount;
  final String status; // PLANNED, ONGOING, COMPLETED

  const TripModel({
    required this.id,
    required this.title,
    required this.destination,
    required this.startDate,
    required this.endDate,
    required this.coverImageUrl,
    required this.placesCount,
    required this.memoriesCount,
    required this.status,
  });

  factory TripModel.fromJson(Map<String, dynamic> json) {
    return TripModel(
      id: json['id'] as String,
      title: json['title'] as String,
      destination: json['destination'] as String,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      coverImageUrl: json['coverImageUrl'] as String,
      placesCount: (json['placesCount'] as num).toInt(),
      memoriesCount: (json['memoriesCount'] as num).toInt(),
      status: json['status'] as String,
    );
  }
}
