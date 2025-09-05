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

/// 提供中文名、列表与反序列化工具
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

  /// 通过存储键（enum 名字）还原为枚举
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
