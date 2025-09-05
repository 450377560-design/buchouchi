import 'cuisine.dart';

class Recipe {
  final int? id;
  final String name;
  final Cuisine cuisine;
  final bool isCustom;

  Recipe({
    this.id,
    required this.name,
    required this.cuisine,
    required this.isCustom,
  });

  Recipe copyWith({int? id, String? name, Cuisine? cuisine, bool? isCustom}) {
    return Recipe(
      id: id ?? this.id,
      name: name ?? this.name,
      cuisine: cuisine ?? this.cuisine,
      isCustom: isCustom ?? this.isCustom,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'cuisine': cuisine.key,
    'is_custom': isCustom ? 1 : 0,
  };

  static Recipe fromMap(Map<String, dynamic> m) => Recipe(
    id: m['id'] as int?,
    name: m['name'] as String,
    cuisine: CuisineX.fromKey(m['cuisine'] as String),
    isCustom: (m['is_custom'] as int) == 1,
  );
}
