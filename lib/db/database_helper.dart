import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/cuisine.dart';
import '../models/recipe.dart';
import '../models/ingredient.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const _dbName = 'buchouchi.db';
  // 升级版本：为 recipes 表加 image_url、instructions，并扩充初始数据
  static const _dbVersion = 2;

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
        FOREIGN KEY(recipe_id) REFERENCES recipes(id) ON DELETE CASCADE
      );
    ''');

    await _seed(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // 兼容老用户：升级表结构
      await db.execute('ALTER TABLE recipes ADD COLUMN image_url TEXT;');
      await db.execute('ALTER TABLE recipes ADD COLUMN instructions TEXT;');
      // 不再自动大量插入，避免重复；新装才会跑 _seed
    }
  }

  // ============ 初始数据（八大菜系 + 扩充） ============
  Future<void> _seed(Database db) async {
    Future<int> addRecipe({
      required String name,
      required Cuisine c,
      String? imageUrl,
      String? instructions,
      List<String> ingredients = const [],
    }) async {
      final rid = await db.insert('recipes', {
        'name': name,
        'cuisine': c.key,
        'is_custom': 0,
        'image_url': imageUrl ?? _placeholderFor(name),
        'instructions': (instructions ?? _defaultSteps(name)).trim(),
      });
      for (final n in ingredients) {
        await db.insert('ingredients', {
          'recipe_id': rid,
          'name': n.trim(),
          'is_owned': 0,
        });
      }
      return rid;
    }

    // ===== 川菜 =====
    await addRecipe(
      name: '宫保鸡丁',
      c: Cuisine.chuancai,
      ingredients: ['鸡胸肉', '花生米', '干辣椒', '花椒', '葱姜蒜', '生抽', '老抽', '醋', '白糖', '淀粉'],
      instructions: '''
1) 鸡胸肉切丁，生抽、淀粉腌10分钟；
2) 花生米冷油小火炸香捞出；干辣椒、花椒备用；
3) 炒锅热油，下干辣椒花椒爆香，下鸡丁滑炒至变白；
4) 加葱姜蒜、调料汁（生抽/老抽/醋/糖/水淀粉）翻匀；
5) 大火收汁，关火撒花生米，快速翻匀出锅。
''',
    );
    await addRecipe(
      name: '麻婆豆腐',
      c: Cuisine.chuancai,
      ingredients: ['北豆腐', '牛肉末', '郫县豆瓣', '花椒粉', '辣椒粉', '葱姜蒜', '生抽', '高汤', '水淀粉'],
      instructions: '''
1) 豆腐切小块焯水去豆腥；牛肉末用少许生抽抓匀；
2) 锅内下油，煸香豆瓣酱出红油，加入牛肉末炒散；
3) 加入高汤，放入豆腐小火煮5分钟；
4) 调入花椒粉、辣椒粉，轻推防破；
5) 水淀粉勾薄芡，淋热油，撒葱花出锅。
''',
    );
    await addRecipe(
      name: '水煮鱼',
      c: Cuisine.chuancai,
      ingredients: ['草鱼片', '豆芽', '生菜', '郫县豆瓣', '干辣椒', '花椒', '姜蒜', '料酒', '蛋清', '淀粉'],
      instructions: '''
1) 鱼片用蛋清、淀粉、料酒抓匀腌制；
2) 锅中炒豆瓣、姜蒜出香，加水或高汤煮开；
3) 下豆芽、生菜烫熟铺底；
4) 下鱼片小火滑至变白即关火；
5) 另起油爆香干辣椒花椒，浇在鱼片上。
''',
    );
    await addRecipe(
      name: '回锅肉',
      c: Cuisine.chuancai,
      ingredients: ['五花肉', '青蒜', '郫县豆瓣', '甜面酱', '生抽', '料酒', '姜片'],
      instructions: '''
1) 五花肉冷水下锅加姜片料酒煮至七成熟，捞出冷却切薄片；
2) 锅内少油，下肉片小火煸出油卷曲；
3) 推入豆瓣、甜面酱炒匀上色；
4) 下青蒜段快速翻匀出锅。
''',
    );
    await addRecipe(
      name: '鱼香肉丝',
      c: Cuisine.chuancai,
      ingredients: ['里脊肉', '木耳', '胡萝卜', '泡椒', '葱姜蒜', '生抽', '醋', '糖', '郫县豆瓣', '水淀粉'],
      instructions: '''
1) 里脊切丝，少许生抽淀粉腌；木耳胡萝卜切丝；
2) 炒锅下油，爆香葱姜蒜与泡椒、豆瓣；
3) 下肉丝滑散，下蔬菜丝翻炒；
4) 加入“糖醋+生抽+水淀粉”调味，收汁出锅。
''',
    );

    // ===== 粤菜 =====
    await addRecipe(
      name: '白切鸡',
      c: Cuisine.yuecai,
      ingredients: ['三黄鸡', '姜', '葱', '盐', '生抽', '香油'],
      instructions: '''
1) 全鸡冷水下锅，加姜葱小火15分钟关火焖10分钟；
2) 捞出浸冰水定型，沥干抹少许香油；
3) 斩件，佐姜葱油或豉油食之。
''',
    );
    await addRecipe(
      name: '豉汁蒸排骨',
      c: Cuisine.yuecai,
      ingredients: ['排骨', '豆豉', '蒜蓉', '生抽', '糖', '淀粉', '料酒', '青红椒'],
      instructions: '''
1) 排骨冲洗控水，加生抽糖料酒、蒜蓉、豆豉抓匀，拌少许淀粉腌30分钟；
2) 入蒸锅大火蒸15-20分钟；
3) 撒青红椒圈，出锅。
''',
    );
    await addRecipe(
      name: '清蒸鲈鱼',
      c: Cuisine.yuecai,
      ingredients: ['鲈鱼', '姜丝', '葱丝', '蒸鱼豉油', '花生油'],
      instructions: '''
1) 鲈鱼去腥处理，腹中垫姜丝；
2) 水开上汽后入锅，大火蒸6-8分钟（视大小调整）；
3) 倒掉蒸出的水，铺葱姜丝，浇热油与蒸鱼豉油。
''',
    );
    await addRecipe(
      name: '干炒牛河',
      c: Cuisine.yuecai,
      ingredients: ['河粉', '牛肉片', '芽菜/豆芽', '葱段', '生抽', '老抽', '蚝油', '胡椒'],
      instructions: '''
1) 牛肉片用生抽淀粉抓匀；河粉拨散；
2) 大火热锅下油，先爆牛肉至变色盛出；
3) 下葱段豆芽快炒，加入河粉与调味；
4) 回锅牛肉，大火翻匀出锅。
''',
    );
    await addRecipe(
      name: '叉烧',
      c: Cuisine.yuecai,
      ingredients: ['梅花肉', '叉烧酱', '蜂蜜', '生抽'],
      instructions: '''
1) 梅花肉用叉烧酱、生抽腌过夜；
2) 烤箱200℃烤20分钟，刷蜂蜜再烤5-8分钟；
3) 静置回温切片。
''',
    );

    // ===== 苏菜 =====
    await addRecipe(
      name: '松鼠桂鱼',
      c: Cuisine.sucai,
      ingredients: ['桂鱼', '淀粉', '番茄酱', '白糖', '醋', '盐', '葱姜蒜'],
    );
    await addRecipe(
      name: '红烧狮子头',
      c: Cuisine.sucai,
      ingredients: ['猪肉糜', '荸荠', '葱姜', '鸡蛋', '生抽', '老抽', '淀粉', '高汤', '青菜心'],
      instructions: '''
1) 肉糜加蛋清、葱姜末、荸荠碎、生抽淀粉拌打上劲；
2) 油锅中火定型炸至表面金黄；
3) 砂锅入高汤、老抽，放狮子头小火焖30分钟；
4) 青菜心汆水垫底，装盘。
''',
    );
    await addRecipe(
      name: '叫花鸡',
      c: Cuisine.sucai,
      ingredients: ['三黄鸡', '香菇', '笋', '咸肉', '葱姜', '黄酒', '荷叶', '锡纸'],
      instructions: '''
1) 全鸡擦干，腹中塞香菇笋咸肉与葱姜；
2) 黄酒抹匀外表，用荷叶与锡纸层层包裹；
3) 烤箱180℃烤1.5小时，拆包出香。
''',
    );
    await addRecipe(
      name: '酱鸭',
      c: Cuisine.sucai,
      ingredients: ['鸭子', '黄酒', '酱油', '冰糖', '八角', '桂皮', '姜葱'],
      instructions: '''
1) 鸭身焯水去血沫；
2) 砂锅下油糖炒色，入酱油、黄酒与香料；
3) 加水没过，小火焖至入味收汁；晾凉切件。
''',
    );

    // ===== 浙菜 =====
    await addRecipe(
      name: '西湖醋鱼',
      c: Cuisine.zhecai,
      ingredients: ['草鱼', '姜', '葱', '黄酒', '醋', '白糖', '酱油'],
    );
    await addRecipe(
      name: '东坡肉',
      c: Cuisine.zhecai,
      ingredients: ['五花肉', '黄酒', '冰糖', '生抽', '老抽', '葱姜'],
      instructions: '''
1) 五花肉切方块焯水；砂锅垫葱姜；
2) 放入肉块加黄酒、生抽老抽、冰糖，几乎不加水；
3) 小火慢焖1.5-2小时，期间翻面一次，汤浓肉酥即可。
''',
    );
    await addRecipe(
      name: '龙井虾仁',
      c: Cuisine.zhecai,
      ingredients: ['河虾仁', '龙井茶', '蛋清', '淀粉', '盐'],
      instructions: '''
1) 虾仁洗净去腥，蛋清淀粉上浆；
2) 茶叶温水泡开取茶汤；
3) 锅内滑油至虾仁变白，倒出沥油；
4) 另起锅入茶汤，回虾仁略收即可。
''',
    );
    await addRecipe(
      name: '油焖春笋',
      c: Cuisine.zhecai,
      ingredients: ['春笋', '酱油', '糖', '葱姜', '油'],
      instructions: '''
1) 春笋焯水去涩切滚刀；
2) 锅中下油、葱姜，入笋块煸香；
3) 加生抽与糖，小火焖至入味收汁。
''',
    );

    // ===== 闽菜 =====
    await addRecipe(
      name: '佛跳墙',
      c: Cuisine.mincai,
      ingredients: ['鲍鱼', '海参', '干贝', '花菇', '冬笋', '绍兴黄酒', '火腿'],
    );
    await addRecipe(
      name: '海蛎煎',
      c: Cuisine.mincai,
      ingredients: ['海蛎', '地瓜粉', '鸡蛋', '韭菜', '蒜蓉', '胡椒'],
      instructions: '''
1) 海蛎冲洗控干；地瓜粉与少量水拌糊；
2) 热锅下油，倒入粉糊与海蛎，摊匀；
3) 淋蛋液铺韭菜，煎至两面金黄，撒胡椒。
''',
    );
    await addRecipe(
      name: '卤面',
      c: Cuisine.mincai,
      ingredients: ['面条', '瘦肉丝', '香菇', '木耳', '鱿鱼', '笋干', '生抽', '蚝油', '高汤'],
      instructions: '''
1) 配料切丝爆香，加入高汤与调味；
2) 面条煮至七分捞出，入卤中拌煮吸汁；
3) 出锅撒葱花。
''',
    );
    await addRecipe(
      name: '荔枝肉',
      c: Cuisine.mincai,
      ingredients: ['里脊肉', '番茄酱', '糖', '醋', '淀粉', '鸡蛋'],
      instructions: '''
1) 里脊切块裹蛋液淀粉炸至金黄；
2) 锅内调糖醋汁与番茄酱，加热至粘稠；
3) 下炸肉快速翻匀裹汁出锅。
''',
    );

    // ===== 湘菜 =====
    await addRecipe(
      name: '剁椒鱼头',
      c: Cuisine.xiangcai,
      ingredients: ['胖头鱼头', '剁椒', '姜', '蒜', '小葱', '料酒', '蒸鱼豉油'],
    );
    await addRecipe(
      name: '毛氏红烧肉',
      c: Cuisine.xiangcai,
      ingredients: ['五花肉', '冰糖', '生抽', '老抽', '啤酒/水', '八角'],
      instructions: '''
1) 五花肉焯水切块；炒糖色下肉翻匀上色；
2) 加生抽老抽、啤酒/水与香料，小火焖40-60分钟；
3) 大火收汁油亮即可。
''',
    );
    await addRecipe(
      name: '辣椒炒肉',
      c: Cuisine.xiangcai,
      ingredients: ['二荆条/小米椒', '五花/前腿肉', '蒜', '生抽', '老抽'],
      instructions: '''
1) 肉切薄片过油滑炒盛出；
2) 锅内爆香蒜片，入辣椒翻炒；
3) 回锅肉片，烹生抽少许老抽，快炒出锅。
''',
    );
    await addRecipe(
      name: '口味虾',
      c: Cuisine.xiangcai,
      ingredients: ['小龙虾', '豆瓣', '姜蒜', '花椒', '啤酒', '小葱'],
      instructions: '''
1) 小龙虾洗刷处理干净；
2) 炒锅下油与豆瓣、花椒、姜蒜爆香；
3) 入小龙虾翻炒，倒啤酒焖8-10分钟；
4) 收汁亮油，撒葱花出锅。
''',
    );

    // ===== 徽菜 =====
    await addRecipe(
      name: '臭鳜鱼',
      c: Cuisine.huicai,
      ingredients: ['鳜鱼', '盐', '黄酒', '姜', '蒸鱼豉油', '辣椒'],
    );
    await addRecipe(
      name: '笋干烧肉',
      c: Cuisine.huicai,
      ingredients: ['五花肉', '笋干', '生抽', '老抽', '冰糖', '姜葱'],
      instructions: '''
1) 笋干泡发；五花焯水切块；
2) 砂锅放肉与笋干，加调味与热水小火焖45分钟；
3) 收汁出锅。
''',
    );
    await addRecipe(
      name: '徽州一品锅',
      c: Cuisine.huicai,
      ingredients: ['五花肉', '豆腐', '白菜', '粉丝', '干香菇', '高汤', '酱油'],
      instructions: '''
1) 砂锅垫白菜与粉丝，码入肉片、豆腐、香菇；
2) 倒入高汤与酱油，小火焖煮至熟透入味。
''',
    );
    await addRecipe(
      name: '毛豆腐',
      c: Cuisine.huicai,
      ingredients: ['毛豆腐', '蒜', '小米椒', '生抽', '香醋'],
      instructions: '''
1) 毛豆腐煎至两面金黄；
2) 加蒜末小米椒、生抽醋炒匀出锅。
''',
    );

    // ===== 鲁菜 =====
    await addRecipe(
      name: '葱爆海参',
      c: Cuisine.lucai,
      ingredients: ['海参', '大葱', '姜', '酱油', '盐', '料酒'],
    );
    await addRecipe(
      name: '九转大肠',
      c: Cuisine.lucai,
      ingredients: ['肥肠', '糖', '醋', '酱油', '葱姜蒜', '八角'],
      instructions: '''
1) 肥肠处理干净焯水；切段；
2) 炒糖色，下葱姜蒜与调味，入大肠小火收汁；
3) 味型酸甜香。
''',
    );
    await addRecipe(
      name: '糖醋鲤鱼',
      c: Cuisine.lucai,
      ingredients: ['鲤鱼', '淀粉', '糖', '醋', '番茄酱', '葱姜'],
      instructions: '''
1) 鲤鱼处理打花刀，拍粉炸至外酥；
2) 调糖醋汁（糖/醋/番茄酱），勾薄芡；
3) 浇汁上桌。
''',
    );
    await addRecipe(
      name: '四喜丸子',
      c: Cuisine.lucai,
      ingredients: ['猪肉糜', '鸡蛋', '面包糠/淀粉', '葱姜', '生抽', '糖', '高汤'],
      instructions: '''
1) 肉糜加调味与蛋清拌打上劲，成丸；
2) 过油炸定型后入高汤小火焖15分钟；
3) 勾薄芡出锅。
''',
    );
  }

  static String _placeholderFor(String name) =>
      'https://picsum.photos/seed/${Uri.encodeComponent(name)}/800/500';

  static String _defaultSteps(String name) => '''
1) 准备好食材并完成基础处理；
2) 热锅冷油依次下主辅料；
3) 调味后根据口感收汁或焖煮；
4) 出锅装盘，即成《$name》。
''';

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
