import 'package:flutter/foundation.dart';

/// A place category from `GET /api/explore/categories`.
@immutable
class CategoryModel {
  final int id;
  final String name;
  final int? parentCategoryId;

  const CategoryModel({required this.id, required this.name, this.parentCategoryId});

  factory CategoryModel.fromJson(Map<String, dynamic> json) => CategoryModel(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String? ?? '',
        parentCategoryId: (json['parentCategoryId'] as num?)?.toInt(),
      );
}
