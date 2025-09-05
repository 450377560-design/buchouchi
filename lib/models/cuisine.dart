enum Cuisine {
  chuancai,  // 川
  yuecai,    // 粤
  sucai,     // 苏
  zhecai,    // 浙
  mincai,    // 闽
  xiangcai,  // 湘
  huicai,    // 徽
  lucai,     // 鲁
  custom,    // 自定义专区
}

extension CuisineX on Cuisine {
  String get zh {
    switch (this) {
      case Cuisine.chuancai: return '川菜';
      case Cuisine.yuecai:   return '粤菜';
      case Cuisine.sucai:    return '苏菜';
      case Cuisine.zhecai:   return '浙菜';
      case Cuisine.mincai:   return '闽菜';
      case Cuisine.xiangcai: return '湘菜';
      case Cuisine.huicai:   return '徽菜';
      case Cuisine.lucai:    return '鲁菜';
      case Cuisine.custom:   return '自定义菜谱';
    }
  }

  String get key => toString().split('.').last;

  static Cuisine fromKey(String key) {
    return Cuisine.values.firstWhere(
      (c) => c.key == key,
      orElse: () => Cuisine.custom,
    );
  }

  static List<Cuisine> get eight => [
    Cuisine.chuancai, Cuisine.yuecai, Cuisine.sucai, Cuisine.zhecai,
    Cuisine.mincai, Cuisine.xiangcai, Cuisine.huicai, Cuisine.lucai,
  ];
}
