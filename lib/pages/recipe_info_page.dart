import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../models/cuisine.dart'; // ⬅️ 必须直接引入，才能使用 c.zh 扩展
import 'recipe_detail_page.dart';

class RecipeInfoPage extends StatelessWidget {
  final Recipe recipe;
  const RecipeInfoPage({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    final img = (recipe.imageUrl?.trim().isNotEmpty ?? false)
        ? recipe.imageUrl!.trim()
        : 'https://picsum.photos/seed/${Uri.encodeComponent(recipe.name)}/800/500';
    final text = (recipe.instructions?.trim().isNotEmpty ?? false)
        ? recipe.instructions!.trim()
        : '暂无做法，稍后补充～';

    return Scaffold(
      appBar: AppBar(title: Text(recipe.name)),
      body: ListView(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Image.network(
              img,
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
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text(recipe.cuisine.zh)),
                    if (recipe.isCustom) const Chip(label: Text('自定义')),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('烹饪方法', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SelectableText(text),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => RecipeDetailPage(recipe: recipe),
                    ));
                  },
                  icon: const Icon(Icons.list_alt),
                  label: const Text('查看/勾选原料清单'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
