/// 八大菜系 + 自定义
enum Cuisine {
  chuancai, // 川
  yuecai,   // 粤
  sucai,    // 苏
  zhecai,   // 浙
  mincai,   // 闽
  xiangcai, // 湘
  huicai,   // 徽
  lucai,    // 鲁
  custom,   // 自定义
}

/// 工具：中文名、列表、反序列化
class CuisineX {
  /// 八大菜系列表（不含自定义）
  static const List<Cuisine> eight = [
    Cuisine.chuancai,
    Cuisine.yuecai,
    Cuisine.sucai,
    Cuisine.zhecai,
    Cuisine.mincai,
    Cuisine.xiangcai,
    Cuisine.huicai,
    Cuisine.lucai,
  ];

  /// 通过键（enum 名字）还原
  static Cuisine fromKey(String key) {
    switch (key) {
      case 'chuancai':
        return Cuisine.chuancai;
      case 'yuecai':
        return Cuisine.yuecai;
      case 'sucai':
        return Cuisine.sucai;
      case 'zhecai':
        return Cuisine.zhecai;
      case 'mincai':
        return Cuisine.mincai;
      case 'xiangcai':
        return Cuisine.xiangcai;
      case 'huicai':
        return Cuisine.huicai;
      case 'lucai':
        return Cuisine.lucai;
      case 'custom':
      default:
        return Cuisine.custom;
    }
  }

  /// 枚举 -> 中文名
  static String zh(Cuisine c) {
    switch (c) {
      case Cuisine.chuancai:
        return '川菜';
      case Cuisine.yuecai:
        return '粤菜';
      case Cuisine.sucai:
        return '苏菜';
      case Cuisine.zhecai:
        return '浙菜';
      case Cuisine.mincai:
        return '闽菜';
      case Cuisine.xiangcai:
        return '湘菜';
      case Cuisine.huicai:
        return '徽菜';
      case Cuisine.lucai:
        return '鲁菜';
      case Cuisine.custom:
        return '自定义';
    }
  }
}

/// 给枚举加便捷 getter：c.key / c.zh
extension CuisineExt on Cuisine {
  /// 用于数据库的键（与 enum 名一致）
  String get key => name; // Dart 2.17+ 提供 enum.name
  /// 中文名
  String get zh => CuisineX.zh(this);
}
