/// 八大菜系 + 自定义
enum Cuisine {
  chuancai, yuecai, sucai, zhecai, mincai, xiangcai, huicai, lucai, custom,
}

class CuisineX {
  static const List<Cuisine> eight = [
    Cuisine.chuancai, Cuisine.yuecai, Cuisine.sucai, Cuisine.zhecai,
    Cuisine.mincai, Cuisine.xiangcai, Cuisine.huicai, Cuisine.lucai,
  ];

  static Cuisine fromKey(String key) {
    switch (key) {
      case 'chuancai': return Cuisine.chuancai;
      case 'yuecai':   return Cuisine.yuecai;
      case 'sucai':    return Cuisine.sucai;
      case 'zhecai':   return Cuisine.zhecai;
      case 'mincai':   return Cuisine.mincai;
      case 'xiangcai': return Cuisine.xiangcai;
      case 'huicai':   return Cuisine.huicai;
      case 'lucai':    return Cuisine.lucai;
      case 'custom':
      default:         return Cuisine.custom;
    }
  }

  static String zh(Cuisine c) {
    switch (c) {
      case Cuisine.chuancai: return '川菜';
      case Cuisine.yuecai:   return '粤菜';
      case Cuisine.sucai:    return '苏菜';
      case Cuisine.zhecai:   return '浙菜';
      case Cuisine.mincai:   return '闽菜';
      case Cuisine.xiangcai: return '湘菜';
      case Cuisine.huicai:   return '徽菜';
      case Cuisine.lucai:    return '鲁菜';
      case Cuisine.custom:   return '自定义';
    }
  }
}

extension CuisineExt on Cuisine {
  String get key => name;
  String get zh  => CuisineX.zh(this);
}
