import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/cuisine.dart';
import '../models/ingredient.dart';
import '../models/recipe.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const _dbName = 'buchouchi.db';
  // v2: recipes 加 image_url、instructions
  // v3: ingredients 加 is_custom、suggest_qty
  // v4: 今日食谱 & 用量自定义
  static const _dbVersion = 4;

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
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE recipes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        cuisine TEXT NOT NULL,
        is_custom INTEGER NOT NULL DEFAULT 0,
        image_url TEXT,
        instructions TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE ingredients(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        recipe_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        is_owned INTEGER NOT NULL DEFAULT 0,
        is_custom INTEGER NOT NULL DEFAULT 0,
        suggest_qty TEXT,
        FOREIGN KEY(recipe_id) REFERENCES recipes(id) ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE TABLE today_recipe(
        dt TEXT NOT NULL,
        recipe_id INTEGER NOT NULL,
        PRIMARY KEY (dt, recipe_id),
        FOREIGN KEY(recipe_id) REFERENCES recipes(id) ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE TABLE today_custom_qty(
        dt TEXT NOT NULL,
        name TEXT NOT NULL,
        user_qty TEXT,
        PRIMARY KEY (dt, name)
      );
    ''');

    await _seed(db);
    await _importFromAssetIfAny(db, 'assets/recipes/seed_more.json');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE recipes ADD COLUMN image_url TEXT;');
      await db.execute('ALTER TABLE recipes ADD COLUMN instructions TEXT;');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE ingredients ADD COLUMN is_custom INTEGER NOT NULL DEFAULT 0;');
      await db.execute('ALTER TABLE ingredients ADD COLUMN suggest_qty TEXT;');
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS today_recipe(
          dt TEXT NOT NULL,
          recipe_id INTEGER NOT NULL,
          PRIMARY KEY (dt, recipe_id),
          FOREIGN KEY(recipe_id) REFERENCES recipes(id) ON DELETE CASCADE
        );
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS today_custom_qty(
          dt TEXT NOT NULL,
          name TEXT NOT NULL,
          user_qty TEXT,
          PRIMARY KEY (dt, name)
        );
      ''');
    }
  }

  // ================== 基础样例（简化版） ==================
  Future<void> _seed(Database db) async {
    Future<int> addRecipe({
      required String name,
      required Cuisine c,
      String? imageUrl,
      String? instructions,
      List<Map<String, String>> ingredients = const [], // {name, suggest?}
    }) async {
      final rid = await db.insert('recipes', {
        'name': name,
        'cuisine': c.key,
        'is_custom': 0,
        'image_url': imageUrl,
        'instructions': (instructions ?? _defaultSteps(name)).trim(),
      });
      for (final m in ingredients) {
        await db.insert('ingredients', {
          'recipe_id': rid,
          'name': m['name']!.trim(),
          'is_owned': 0,
          'is_custom': 0,
          'suggest_qty': m['suggest'],
        });
      }
      return rid;
    }

    await addRecipe(
      name: '宫保鸡丁',
      c: Cuisine.chuancai,
      ingredients: [
        {'name':'鸡胸肉','suggest':'300g'},
        {'name':'花生米','suggest':'80g'},
        {'name':'干辣椒'},
        {'name':'花椒'},
        {'name':'葱姜蒜'},
      ],
    );

    await addRecipe(
      name: '白切鸡',
      c: Cuisine.yuecai,
      ingredients: [
        {'name':'三黄鸡','suggest':'1只'},
        {'name':'姜葱'},
        {'name':'盐'},
      ],
    );

    await addRecipe(
      name: '红烧狮子头',
      c: Cuisine.sucai,
      ingredients: [
        {'name':'猪肉糜','suggest':'500g'},
        {'name':'荸荠','suggest':'6个'},
        {'name':'鸡蛋','suggest':'1个'},
      ],
    );

    await addRecipe(
      name: '东坡肉',
      c: Cuisine.zhecai,
      ingredients: [
        {'name':'五花肉','suggest':'800g'},
        {'name':'黄酒','suggest':'1碗'},
        {'name':'冰糖','suggest':'30g'},
      ],
    );
  }

  static String _defaultSteps(String name) => '''
1) 准备好食材并完成基础处理；
2) 热锅冷油依次下主辅料；
3) 调味后根据口感收汁或焖煮；
4) 出锅装盘，即成《$name》。
''';

  // ========== 批量导入（assets/recipes/seed_more.json） ==========
  Future<void> _importFromAssetIfAny(Database db, String assetPath) async {
    try {
      final text = await rootBundle.loadString(assetPath);
      final data = json.decode(text);
      if (data is! List) return;
      for (final item in data) {
        final name = (item['name'] ?? '').toString().trim();
        if (name.isEmpty) continue;
        final cuisine = CuisineX.fromKey((item['cuisine'] ?? 'custom').toString());
        final exists = (await db.query('recipes',
            where: 'name = ? AND cuisine = ?', whereArgs: [name, cuisine.key])).isNotEmpty;
        if (exists) continue;

        final rid = await db.insert('recipes', {
          'name': name,
          'cuisine': cuisine.key,
          'is_custom': 0,
          'image_url': item['image_url'],
          'instructions': (item['instructions'] ?? _defaultSteps(name)).toString(),
        });

        final ings = (item['ingredients'] as List?) ?? [];
        for (final i in ings) {
          await db.insert('ingredients', {
            'recipe_id': rid,
            'name': (i['name'] ?? '').toString(),
            'is_owned': 0,
            'is_custom': 0,
            'suggest_qty': (i['suggest'] ?? '').toString().isEmpty ? null : i['suggest'],
          });
        }
      }
    } catch (_) {
      // asset 不存在或格式问题，忽略即可
    }
  }

  // ================== CRUD：Recipe ==================
  Future<List<Recipe>> getRecipesByCuisine(Cuisine c) async {
    final d = await db;
    final maps = await d.query('recipes', where: 'cuisine = ?', whereArgs: [c.key], orderBy: 'id DESC');
    return maps.map(Recipe.fromMap).toList();
  }

  Future<List<Recipe>> getCustomRecipes() async {
    final d = await db;
    final maps = await d.query('recipes', where: 'is_custom = 1', orderBy: 'id DESC');
    return maps.map(Recipe.fromMap).toList();
  }

  Future<int> addRecipe(Recipe r, {List<Map<String,String>> initIngredients = const []}) async {
    final d = await db;
    final rid = await d.insert('recipes', r.toMap());
    for (final m in initIngredients) {
      await d.insert('ingredients', {
        'recipe_id': rid,
        'name': m['name']!.trim(),
        'is_owned': 0,
        'is_custom': 1,
        'suggest_qty': m['suggest'],
      });
    }
    return rid;
  }

  Future<void> deleteRecipe(int recipeId) async {
    final d = await db;
    await d.delete('ingredients', where: 'recipe_id = ?', whereArgs: [recipeId]);
    await d.delete('recipes', where: 'id = ?', whereArgs: [recipeId]);
  }

  // ================== CRUD：Ingredient ==================
  Future<List<Ingredient>> getIngredients(int recipeId) async {
    final d = await db;
    final maps = await d.query('ingredients', where: 'recipe_id = ?', whereArgs: [recipeId], orderBy: 'id ASC');
    return maps.map(Ingredient.fromMap).toList();
  }

  Future<int> addIngredient(int recipeId, String name, {String? suggestQty}) async {
    final d = await db;
    return d.insert('ingredients', {
      'recipe_id': recipeId,
      'name': name.trim(),
      'is_owned': 0,
      'is_custom': 1,
      'suggest_qty': suggestQty,
    });
  }

  Future<void> setIngredientOwned(int ingredientId, bool owned) async {
    final d = await db;
    await d.update('ingredients', {'is_owned': owned ? 1 : 0}, where: 'id = ?', whereArgs: [ingredientId]);
  }

  Future<void> deleteIngredient(int ingredientId) async {
    final d = await db;
    await d.delete('ingredients', where: 'id = ?', whereArgs: [ingredientId]);
  }

  // ================== 今日食谱 ==================
  String get today => DateTime.now().toLocal().toIso8601String().substring(0,10);

  Future<void> toggleToday(int recipeId, {bool? setTo}) async {
    final d = await db;
    final dt = today;
    final exists = await d.query('today_recipe', where: 'dt = ? AND recipe_id = ?', whereArgs: [dt, recipeId]);
    if (setTo == true || (setTo == null && exists.isEmpty)) {
      await d.insert('today_recipe', {'dt': dt, 'recipe_id': recipeId}, conflictAlgorithm: ConflictAlgorithm.ignore);
    } else {
      await d.delete('today_recipe', where: 'dt = ? AND recipe_id = ?', whereArgs: [dt, recipeId]);
    }
  }

  Future<List<Recipe>> getTodayRecipes() async {
    final d = await db;
    final dt = today;
    final rows = await d.rawQuery('''
      SELECT r.* FROM recipes r
      INNER JOIN today_recipe t ON r.id = t.recipe_id
      WHERE t.dt = ?
      ORDER BY r.id DESC
    ''', [dt]);
    return rows.map(Recipe.fromMap).toList();
  }

  /// 汇总“今日食谱”的去重原料；返回：[{'name','suggest','user'}]
  Future<List<Map<String,String?>>> getTodayIngredientSummary() async {
    final d = await db;
    final dt = today;
    final rows = await d.rawQuery('''
      SELECT i.name, GROUP_CONCAT(i.suggest_qty, ' + ') AS suggest
      FROM ingredients i
      INNER JOIN today_recipe t ON i.recipe_id = t.recipe_id AND t.dt = ?
      GROUP BY i.name
      ORDER BY i.name COLLATE NOCASE ASC
    ''', [dt]);

    final customRows = await d.query('today_custom_qty', where: 'dt = ?', whereArgs: [dt]);
    final customMap = { for (final r in customRows) r['name'] as String : r['user_qty'] as String? };

    return rows.map((r) => {
      'name': r['name'] as String,
      'suggest': (r['suggest'] as String?)?.isEmpty ?? true ? null : r['suggest'] as String?,
      'user': customMap[r['name'] as String],
    }).toList();
  }

  Future<void> upsertTodayUserQty(String name, String? userQty) async {
    final d = await db;
    final dt = today;
    await d.insert('today_custom_qty', {'dt': dt, 'name': name, 'user_qty': userQty},
      conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ================== 图片：维基百科解析并缓存到 recipes.image_url ==================
  Future<String?> resolveAndCacheImage(int recipeId, String name) async {
    final d = await db;
    // 先看有没有缓存
    final rec = await d.query('recipes', where: 'id = ?', whereArgs: [recipeId], limit: 1);
    if (rec.isNotEmpty && (rec.first['image_url'] as String?)?.isNotEmpty == true) {
      return rec.first['image_url'] as String;
    }
    final url = await _wikipediaThumb(name) ?? await _wikipediaThumb(name, lang: 'en');
    if (url != null) {
      await d.update('recipes', {'image_url': url}, where: 'id = ?', whereArgs: [recipeId]);
    }
    return url;
  }

  Future<String?> _wikipediaThumb(String title, {String lang = 'zh'}) async {
    try {
      final api = Uri.https('$lang.wikipedia.org', '/api/rest_v1/page/summary/$title');
      final resp = await http.get(api);
      if (resp.statusCode == 200) {
        final j = json.decode(utf8.decode(resp.bodyBytes));
        final thumb = j['originalimage']?['source'] ?? j['thumbnail']?['source'];
        if (thumb is String && thumb.isNotEmpty) return thumb;
      }
    } catch (_) {}
    return null;
  }
}
