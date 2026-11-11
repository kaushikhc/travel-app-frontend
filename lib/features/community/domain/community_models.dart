import 'package:flutter/foundation.dart';
import '../../../core/time/api_time.dart';

/// Author of a post (`PostView.Author`).
@immutable
class PostAuthor {
  final int id;
  final String displayName;
  final String? photoUrl;

  const PostAuthor({required this.id, required this.displayName, this.photoUrl});

  factory PostAuthor.fromJson(Map<String, dynamic> json) => PostAuthor(
        id: (json['id'] as num).toInt(),
        displayName: json['displayName'] as String? ?? '',
        photoUrl: json['photoUrl'] as String?,
      );
}

/// The place of a shared memory (`PostView.PlaceRef`); [id] opens the place detail.
@immutable
class PostPlace {
  final int id;
  final String name;

  const PostPlace({required this.id, required this.name});

  static PostPlace? fromJson(Object? json) => json is Map<String, dynamic> && json['id'] is num
      ? PostPlace(id: (json['id'] as num).toInt(), name: json['name'] as String? ?? '')
      : null;
}

/// A shared memory in the feed (`PostView`). Media urls are signed links from the response.
@immutable
class PostModel {
  final int id;
  final int memoryId;
  final PostAuthor author;
  final String? caption;
  final String visibility;
  final DateTime? createdAt;
  final int likeCount;
  final bool likedByMe;
  final String memoryTitle;
  final String? memoryNote;
  final DateTime? capturedAt;
  final PostPlace? place;
  final List<String> photoUrls;

  const PostModel({
    required this.id,
    required this.memoryId,
    required this.author,
    this.caption,
    this.visibility = 'PUBLIC',
    this.createdAt,
    this.likeCount = 0,
    this.likedByMe = false,
    this.memoryTitle = '',
    this.memoryNote,
    this.capturedAt,
    this.place,
    this.photoUrls = const <String>[],
  });

  factory PostModel.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> memory = json['memory'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    final List<String> photos = <String>[
      for (final Object? m in memory['media'] as List<dynamic>? ?? const <dynamic>[])
        if (m is Map<String, dynamic> && m['type'] != 'VIDEO' && (m['url'] as String?)?.isNotEmpty == true) m['url'] as String,
    ];
    return PostModel(
      id: (json['id'] as num).toInt(),
      memoryId: (json['memoryId'] as num).toInt(),
      author: PostAuthor.fromJson(json['author'] as Map<String, dynamic>? ?? const <String, dynamic>{'id': 0}),
      caption: json['caption'] as String?,
      visibility: json['visibility'] as String? ?? 'PUBLIC',
      createdAt: ApiTime.parseUtc(json['createdAt'] as String?),
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      likedByMe: json['likedByMe'] as bool? ?? false,
      memoryTitle: memory['title'] as String? ?? '',
      memoryNote: memory['note'] as String?,
      capturedAt: ApiTime.parseUtc(memory['capturedAt'] as String?),
      place: PostPlace.fromJson(memory['place']),
      photoUrls: List<String>.unmodifiable(photos),
    );
  }
}

/// One page of the feed (`FeedPage`).
@immutable
class FeedPage {
  final List<PostModel> posts;
  final int page;
  final bool hasMore;

  const FeedPage({required this.posts, required this.page, required this.hasMore});

  factory FeedPage.fromJson(Map<String, dynamic> json) => FeedPage(
        posts: <PostModel>[
          for (final Object? p in json['posts'] as List<dynamic>? ?? const <dynamic>[])
            if (p is Map<String, dynamic>) PostModel.fromJson(p),
        ],
        page: (json['page'] as num?)?.toInt() ?? 0,
        hasMore: json['hasMore'] as bool? ?? false,
      );
}

/// Another traveler as the community sees them (`TravelerCard`): public fields and counts only.
@immutable
class TravelerCard {
  final int id;
  final String displayName;
  final String? photoUrl;
  final String? bio;
  final int followers;
  final int followingCount;
  final int posts;
  final bool following;
  final bool followsYou;

  const TravelerCard({
    required this.id,
    required this.displayName,
    this.photoUrl,
    this.bio,
    this.followers = 0,
    this.followingCount = 0,
    this.posts = 0,
    this.following = false,
    this.followsYou = false,
  });

  factory TravelerCard.fromJson(Map<String, dynamic> j) => TravelerCard(
        id: (j['id'] as num).toInt(),
        displayName: j['displayName'] as String? ?? '',
        photoUrl: j['photoUrl'] as String?,
        bio: j['bio'] as String?,
        followers: (j['followers'] as num?)?.toInt() ?? 0,
        followingCount: (j['followingCount'] as num?)?.toInt() ?? 0,
        posts: (j['posts'] as num?)?.toInt() ?? 0,
        following: j['following'] as bool? ?? false,
        followsYou: j['followsYou'] as bool? ?? false,
      );
}
