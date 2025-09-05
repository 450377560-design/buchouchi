import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../models/cuisine.dart';
import '../db/database_helper.dart';
import 'recipe_detail_page.dart';

class RecipeInfoPage extends StatefulWidget {
  final Recipe recipe;
  const RecipeInfoPage({super.key, required this.recipe});

  @override
  State<RecipeInfoPage> createState() => _RecipeInfoPageState();
}

class _RecipeInfoPageState extends State<RecipeInfoPage> {
  String? _img;
  final db = DatabaseHelper.instance;

  @override
  void initState() {
    super.initState();
    _loadImg();
  }

  Future<void> _loadImg() async {
    // 优先用缓存image_url，若无则去维基解析并缓存
    final url = await db.resolveAndCacheImage(widget.recipe.id!, widget.recipe.name);
    setState(() => _img = url);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.recipe;
    final text = (r.instructions?.trim().isNotEmpty ?? false)
        ? r.instructions!.trim() : '暂无做法，稍后补充～';

    return Scaffold(
      appBar: AppBar(title: Text(r.name)),
      body: ListView(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: _img == null
                ? const Center(child: CircularProgressIndicator())
                : Image.network(
                    _img!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey.shade200,
                      alignment: Alignment.center,
                      child: const Text('图片加载失败'),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: [
                    Chip(label: Text(r.cuisine.zh)),
                    if (r.isCustom) const Chip(label: Text('自定义')),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('烹饪方法', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SelectableText(text),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => RecipeDetailPage(recipe: r))),
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
}
