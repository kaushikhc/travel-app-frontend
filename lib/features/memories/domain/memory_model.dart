import 'package:flutter/foundation.dart';
import '../../../core/time/api_time.dart';

/// Backend `Memory.Visibility`.
enum MemoryVisibility {
  private,
  friendsOnly,
  public;

  /// The API spelling, e.g. `FRIENDS_ONLY`.
  String get apiName => switch (this) {
        MemoryVisibility.private => 'PRIVATE',
        MemoryVisibility.friendsOnly => 'FRIENDS_ONLY',
        MemoryVisibility.public => 'PUBLIC',
      };

  String get label => switch (this) {
        MemoryVisibility.private => 'Private',
        MemoryVisibility.friendsOnly => 'Friends only',
        MemoryVisibility.public => 'Public',
      };

  static MemoryVisibility fromApi(String? value) => MemoryVisibility.values.firstWhere(
        (MemoryVisibility v) => v.apiName == value?.toUpperCase(),
        orElse: () => MemoryVisibility.private,
      );
}

/// One photo or video of a memory (`MemoryResponse.MediaItem`). [url] is a short-lived signed link.
@immutable
class MemoryMedia {
  final int id;
  final String? type;
  final String? mimeType;
  final int? width;
  final int? height;
  final int displayOrder;
  final String? url;

  const MemoryMedia({
    required this.id,
    this.type,
    this.mimeType,
    this.width,
    this.height,
    this.displayOrder = 0,
    this.url,
  });

  factory MemoryMedia.fromJson(Map<String, dynamic> json) => MemoryMedia(
        id: (json['id'] as num).toInt(),
        type: json['type'] as String?,
        mimeType: json['mimeType'] as String?,
        width: (json['width'] as num?)?.toInt(),
        height: (json['height'] as num?)?.toInt(),
        displayOrder: (json['displayOrder'] as num?)?.toInt() ?? 0,
        url: json['url'] as String?,
      );

  bool get isVideo => (type?.toUpperCase() == 'VIDEO') || (mimeType?.startsWith('video/') ?? false);
}

/// A memory from `MemoryResponse`. Timestamps are UTC.
@immutable
class MemoryModel {
  final int id;
  final int? tripId;
  final int? visitId;
  final int? placeId;
  final String? title;
  final String? note;
  final DateTime? capturedAt;
  final MemoryVisibility visibility;
  final List<String> tags;
  final List<MemoryMedia> media;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const MemoryModel({
    required this.id,
    this.tripId,
    this.visitId,
    this.placeId,
    this.title,
    this.note,
    this.capturedAt,
    this.visibility = MemoryVisibility.private,
    this.tags = const <String>[],
    this.media = const <MemoryMedia>[],
    this.createdAt,
    this.updatedAt,
  });

  factory MemoryModel.fromJson(Map<String, dynamic> json) {
    final List<MemoryMedia> media = (json['media'] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(MemoryMedia.fromJson)
        .toList();
    media.sort((MemoryMedia a, MemoryMedia b) => a.displayOrder.compareTo(b.displayOrder));
    return MemoryModel(
      id: (json['id'] as num).toInt(),
      tripId: (json['tripId'] as num?)?.toInt(),
      visitId: (json['visitId'] as num?)?.toInt(),
      placeId: (json['placeId'] as num?)?.toInt(),
      title: json['title'] as String?,
      note: json['note'] as String?,
      capturedAt: ApiTime.parseUtc(json['capturedAt'] as String?),
      visibility: MemoryVisibility.fromApi(json['visibility'] as String?),
      tags: (json['tags'] as List<dynamic>? ?? const <dynamic>[]).whereType<String>().toList()..sort(),
      media: List<MemoryMedia>.unmodifiable(media),
      createdAt: ApiTime.parseUtc(json['createdAt'] as String?),
      updatedAt: ApiTime.parseUtc(json['updatedAt'] as String?),
    );
  }

  /// The title, or a fallback for memories that only hold a note or photos.
  String get displayTitle => (title == null || title!.trim().isEmpty) ? 'Untitled memory' : title!;

  /// The first photo (not video) in display order, for list thumbnails.
  MemoryMedia? get cover {
    for (final MemoryMedia m in media) {
      if (!m.isVideo) return m;
    }
    return media.isEmpty ? null : media.first;
  }

  /// When it was captured, falling back to when it was saved.
  DateTime? get date => capturedAt ?? createdAt;
}
