class Ingredient {
  final int? id;
  final int recipeId;
  final String name;
  final bool isOwned;
  final bool isCustom;       // ⬅️ 自定义原料
  final String? suggestQty;  // ⬅️ 推荐用量（自由文本：如 “300g / 2根”等）

  Ingredient({
    this.id,
    required this.recipeId,
    required this.name,
    required this.isOwned,
    this.isCustom = false,
    this.suggestQty,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'recipe_id': recipeId,
    'name': name,
    'is_owned': isOwned ? 1 : 0,
    'is_custom': isCustom ? 1 : 0,
    'suggest_qty': suggestQty,
  };

  static Ingredient fromMap(Map<String, dynamic> m) => Ingredient(
    id: m['id'] as int?,
    recipeId: m['recipe_id'] as int,
    name: m['name'] as String,
    isOwned: (m['is_owned'] as int) == 1,
    isCustom: (m['is_custom'] as int? ?? 0) == 1,
    suggestQty: m['suggest_qty'] as String?,
  );
}
