import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../models/ingredient.dart';
import '../db/database_helper.dart';

class RecipeDetailPage extends StatefulWidget {
  final Recipe recipe;
  const RecipeDetailPage({super.key, required this.recipe});

  @override
  State<RecipeDetailPage> createState() => _RecipeDetailPageState();
}

class _RecipeDetailPageState extends State<RecipeDetailPage> {
  final db = DatabaseHelper.instance;
  late Future<List<Ingredient>> _future;
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _future = db.getIngredients(widget.recipe.id!);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = db.getIngredients(widget.recipe.id!);
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.recipe;

    return Scaffold(
      appBar: AppBar(title: Text(r.name)),
      body: FutureBuilder<List<Ingredient>>(
        future: _future,
        builder: (_, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final list = snap.data!;
          final ownedCount = list.where((e) => e.isOwned).length;
          final needCount  = list.length - ownedCount;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Chip(label: Text('已拥有：$ownedCount')),
                    const SizedBox(width: 8),
                    Chip(label: Text('待购买：$needCount')),
                  ],
                ),
              ),
              const Divider(height: 0),
              Expanded(
                child: ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemBuilder: (_, i) {
                    final ing = list[i];
                    return CheckboxListTile(
                      title: Text(ing.name),
                      value: ing.isOwned,
                      onChanged: (v) async {
                        await db.setIngredientOwned(ing.id!, v ?? false);
                        _refresh();
                      },
                    );
                  },
                ),
              ),
              const Divider(height: 0),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          hintText: '添加自定义原料（回车或点+）',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _add(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _add,
                      icon: const Icon(Icons.add),
                      label: const Text('添加'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _add() async {
    final txt = _controller.text.trim();
    if (txt.isEmpty) return;
    await db.addIngredient(widget.recipe.id!, txt);
    _controller.clear();
    _refresh();
  }
}
