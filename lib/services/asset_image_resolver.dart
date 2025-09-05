import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class AssetImageResolver {
  AssetImageResolver._();
  static final AssetImageResolver instance = AssetImageResolver._();

  Map<String, String>? _map; // name -> asset path

  Future<void> _ensureLoaded() async {
    if (_map != null) return;
    try {
      final text = await rootBundle.loadString('assets/recipes/images.json');
      final data = json.decode(text);
      _map = { for (final e in (data as Map).entries) e.key.toString() : e.value.toString() };
    } catch (_) {
      _map = {};
    }
  }

  /// 返回本地 asset 路径（如存在）
  Future<String?> assetFor(String dishName) async {
    await _ensureLoaded();
    return _map![dishName];
  }
}
