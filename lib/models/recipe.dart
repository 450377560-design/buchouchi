import 'cuisine.dart';

class Recipe {
  final int? id;
  final String name;
  final Cuisine cuisine;
  final bool isCustom;

  // 新增：图片与做法
  final String? imageUrl;
  final String? instructions;

  Recipe({
    this.id,
    required this.name,
    required this.cuisine,
    required this.isCustom,
    this.imageUrl,
    this.instructions,
  });

  Recipe copyWith({
    int? id,
    String? name,
    Cuisine? cuisine,
    bool? isCustom,
    String? imageUrl,
    String? instructions,
  }) {
    return Recipe(
      id: id ?? this.id,
      name: name ?? this.name,
      cuisine: cuisine ?? this.cuisine,
      isCustom: isCustom ?? this.isCustom,
      imageUrl: imageUrl ?? this.imageUrl,
      instructions: instructions ?? this.instructions,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'cuisine': cuisine.key,
        'is_custom': isCustom ? 1 : 0,
        'image_url': imageUrl,
        'instructions': instructions,
      };

  static Recipe fromMap(Map<String, dynamic> m) => Recipe(
        id: m['id'] as int?,
        name: m['name'] as String,
        cuisine: CuisineX.fromKey(m['cuisine'] as String),
        isCustom: (m['is_custom'] as int) == 1,
        imageUrl: m['image_url'] as String?,
        instructions: m['instructions'] as String?,
      );
}
