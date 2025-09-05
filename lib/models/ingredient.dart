class Ingredient {
  final int? id;
  final int recipeId;
  final String name;
  final bool isOwned;

  Ingredient({
    this.id,
    required this.recipeId,
    required this.name,
    required this.isOwned,
  });

  Ingredient copyWith({int? id, int? recipeId, String? name, bool? isOwned}) {
    return Ingredient(
      id: id ?? this.id,
      recipeId: recipeId ?? this.recipeId,
      name: name ?? this.name,
      isOwned: isOwned ?? this.isOwned,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'recipe_id': recipeId,
    'name': name,
    'is_owned': isOwned ? 1 : 0,
  };

  static Ingredient fromMap(Map<String, dynamic> m) => Ingredient(
    id: m['id'] as int?,
    recipeId: m['recipe_id'] as int,
    name: m['name'] as String,
    isOwned: (m['is_owned'] as int) == 1,
  );
}
