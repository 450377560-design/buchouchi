import 'package:flutter/material.dart';
import '../models/cuisine.dart';
import '../models/recipe.dart';
import '../db/database_helper.dart';
import 'recipe_info_page.dart';
import 'recipe_edit_page.dart';

class RecipeListPage extends StatefulWidget {
  final Cuisine cuisine;
  const RecipeListPage({super.key, required this.cuisine});

  @override
  State<RecipeListPage> createState() => _RecipeListPageState();
}

class _RecipeListPageState extends State<RecipeListPage> {
  final db = DatabaseHelper.instance;
  late Future<List<Recipe>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Recipe>> _load() {
    return widget.cuisine == Cuisine.custom
        ? db.getCustomRecipes()
        : db.getRecipesByCuisine(widget.cuisine);
  }

  Future<void> _refresh() async => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    final title = widget.cuisine.zh;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: FutureBuilder<List<Recipe>>(
        future: _future,
        builder: (_, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final list = snap.data!;
          if (list.isEmpty) return const Center(child: Text('暂无菜谱'));
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 0),
              itemBuilder: (_, i) {
                final r = list[i];
                return ListTile(
                  title: Text(r.name),
                  subtitle: Text(r.cuisine.zh + (r.isCustom ? ' · 自定义' : '')),
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        tooltip: '加入/移除今日食谱',
                        icon: const Icon(Icons.today),
                        onPressed: () async {
                          await db.toggleToday(r.id!);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('已切换 ${r.name} 的“今日食谱”状态')),
                            );
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: r.id == null ? null : () async {
                          await db.deleteRecipe(r.id!);
                          _refresh();
                        },
                      ),
                    ],
                  ),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => RecipeInfoPage(recipe: r),
                    )).then((_) => _refresh());
                  },
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final ok = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => RecipeEditPage(defaultCuisine: widget.cuisine),
            ),
          );
          if (ok == true && mounted) setState(() {});
        },
        icon: const Icon(Icons.add),
        label: const Text('新增菜谱'), // <- 这里修正了 label
      ),
    );
  }
}
