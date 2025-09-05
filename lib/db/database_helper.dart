import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/cuisine.dart';
import '../models/recipe.dart';
import '../models/ingredient.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const _dbName = 'buchouchi.db';
  static const _dbVersion = 1;

  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _init();
    return _db!;
  }

  Future<Database> _init() async {
    final base = await getDatabasesPath();
    final path = p.join(base, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE recipes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        cuisine TEXT NOT NULL,
        is_custom INTEGER NOT NULL DEFAULT 0
      );
    ''');

    await db.execute('''
      CREATE TABLE ingredients(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        recipe_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        is_owned INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY(recipe_id) REFERENCES recipes(id) ON DELETE CASCADE
      );
    ''');

    await _seed(db);
  }

  Future<void> _seed(Database db) async {
    Future<int> addRecipe(String name, Cuisine c) async {
      return await db.insert('recipes', {
        'name': name,
        'cuisine': c.key,
        'is_custom': 0,
      });
    }

    Future<void> addIngs(int rid, List<String> names) async {
      for (final n in names) {
        await db.insert('ingredients', {
          'recipe_id': rid,
          'name': n,
          'is_owned': 0,
        });
      }
    }

    final r1 = await addRecipe('宫保鸡丁', Cuisine.chuancai);
    await addIngs(r1, ['鸡胸肉', '花生米', '干辣椒', '葱姜蒜', '生抽', '老抽', '醋', '白糖']);

    final r2 = await addRecipe('白切鸡', Cuisine.yuecai);
    await addIngs(r2, ['三黄鸡', '姜', '葱', '盐', '生抽', '香油']);

    final r3 = await addRecipe('松鼠桂鱼', Cuisine.sucai);
    await addIngs(r3, ['桂鱼', '淀粉', '番茄酱', '白糖', '醋', '盐', '葱姜蒜']);

    final r4 = await addRecipe('西湖醋鱼', Cuisine.zhecai);
    await addIngs(r4, ['草鱼', '姜', '葱', '黄酒', '醋', '白糖', '酱油']);

    final r5 = await addRecipe('佛跳墙', Cuisine.mincai);
    await addIngs(r5, ['鲍鱼', '海参', '干贝', '花菇', '冬笋', '绍兴黄酒', '火腿']);

    final r6 = await addRecipe('剁椒鱼头', Cuisine.xiangcai);
    await addIngs(r6, ['胖头鱼头', '剁椒', '姜', '蒜', '小葱', '料酒', '蒸鱼豉油']);

    final r7 = await addRecipe('臭鳜鱼', Cuisine.huicai);
    await addIngs(r7, ['鳜鱼', '盐', '黄酒', '姜', '蒸鱼豉油', '辣椒']);

    final r8 = await addRecipe('葱爆海参', Cuisine.lucai);
    await addIngs(r8, ['海参', '大葱', '姜', '酱油', '盐', '料酒']);
  }

  // ===== Recipes =====
  Future<List<Recipe>> getRecipesByCuisine(Cuisine c) async {
    final d = await db;
    final maps = await d.query('recipes',
        where: 'cuisine = ?', whereArgs: [c.key], orderBy: 'id DESC');
    return maps.map(Recipe.fromMap).toList();
  }

  Future<List<Recipe>> getCustomRecipes() async {
    final d = await db;
    final maps = await d.query('recipes',
        where: 'is_custom = 1', orderBy: 'id DESC');
    return maps.map(Recipe.fromMap).toList();
  }

  Future<int> addRecipe(Recipe r, {List<String> initIngredients = const []}) async {
    final d = await db;
    final rid = await d.insert('recipes', r.toMap());
    for (final n in initIngredients) {
      await d.insert('ingredients', {
        'recipe_id': rid,
        'name': n.trim(),
        'is_owned': 0,
      });
    }
    return rid;
  }

  Future<void> deleteRecipe(int recipeId) async {
    final d = await db;
    await d.delete('ingredients', where: 'recipe_id = ?', whereArgs: [recipeId]);
    await d.delete('recipes', where: 'id = ?', whereArgs: [recipeId]);
  }

  // ===== Ingredients =====
  Future<List<Ingredient>> getIngredients(int recipeId) async {
    final d = await db;
    final maps = await d.query('ingredients',
        where: 'recipe_id = ?', whereArgs: [recipeId], orderBy: 'id ASC');
    return maps.map(Ingredient.fromMap).toList();
  }

  Future<int> addIngredient(int recipeId, String name) async {
    final d = await db;
    return d.insert('ingredients', {
      'recipe_id': recipeId,
      'name': name,
      'is_owned': 0,
    });
  }

  Future<void> setIngredientOwned(int ingredientId, bool owned) async {
    final d = await db;
    await d.update('ingredients', {'is_owned': owned ? 1 : 0},
        where: 'id = ?', whereArgs: [ingredientId]);
  }
}
