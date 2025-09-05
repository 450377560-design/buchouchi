import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../models/cuisine.dart';
import '../db/database_helper.dart';
import '../services/asset_image_resolver.dart';
import 'recipe_detail_page.dart';

class RecipeInfoPage extends StatefulWidget {
  final Recipe recipe;
  const RecipeInfoPage({super.key, required this.recipe});

  @override
  State<RecipeInfoPage> createState() => _RecipeInfoPageState();
}

class _RecipeInfoPageState extends State<RecipeInfoPage> {
  String? _assetPath; // 本地图片
  String? _netUrl;    // 远程图片（仅作兜底）
  final db = DatabaseHelper.instance;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    // 1) 先查本地映射
    final a = await AssetImageResolver.instance.assetFor(widget.recipe.name);
    if (mounted) setState(() => _assetPath = a);

    // 2) 若本地无映射，再尝试用已缓存/解析过的网络图（CI 拉不下来时兜底）
    if (a == null) {
      final url = await db.resolveAndCacheImage(widget.recipe.id!, widget.recipe.name);
      if (mounted) setState(() => _netUrl = url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.recipe;
    final text = (r.instructions?.trim().isNotEmpty ?? false)
        ? r.instructions!.trim() : '暂无做法，稍后补充～';

    Widget img;
    if (_assetPath != null) {
      img = Image.asset(_assetPath!, fit: BoxFit.cover);
    } else if (_netUrl != null) {
      img = Image.network(
        _netUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    } else {
      img = const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(title: Text(r.name)),
      body: ListView(
        children: [
          AspectRatio(aspectRatio: 16 / 9, child: img),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(spacing: 8, runSpacing: 8, children: [
                  Chip(label: Text(r.cuisine.zh)),
                  if (r.isCustom) const Chip(label: Text('自定义')),
                ]),
                const SizedBox(height: 12),
                const Text('烹饪方法', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SelectableText(text),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => RecipeDetailPage(recipe: r))),
                  icon: const Icon(Icons.list_alt),
                  label: const Text('查看/勾选原料清单'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    await db.toggleToday(r.id!, setTo: null);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('已切换 “${r.name}” 的今日食谱状态')),
                      );
                    }
                  },
                  icon: const Icon(Icons.today),
                  label: const Text('加入/移除 今日食谱'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        child: const Text('图片加载失败'),
      );
}
