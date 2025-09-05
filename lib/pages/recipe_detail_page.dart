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

  final _addCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _future = db.getIngredients(widget.recipe.id!);
  }

  Future<void> _refresh() async {
    setState(() => _future = db.getIngredients(widget.recipe.id!));
  }

  @override
  void dispose() {
    _addCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.recipe.name} · 原料')),
      body: FutureBuilder<List<Ingredient>>(
        future: _future,
        builder: (_, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final list = snap.data!;
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemBuilder: (_, i) {
              final ing = list[i];
              return CheckboxListTile(
                value: ing.isOwned,
                onChanged: (v) async {
                  await db.setIngredientOwned(ing.id!, v ?? false);
                  _refresh();
                },
                title: Text(ing.name),
                subtitle: ing.suggestQty == null ? null : Text('建议：${ing.suggestQty}'),
                controlAffinity: ListTileControlAffinity.leading,
                secondary: ing.isCustom
                    ? IconButton(
                        tooltip: '删除该自定义原料',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          await db.deleteIngredient(ing.id!);
                          _refresh();
                        },
                      )
                    : null,
              );
            },
          );
        },
      ),
      bottomSheet: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _addCtrl,
                  decoration: const InputDecoration(
                    labelText: '新增自定义原料',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _qtyCtrl,
                  decoration: const InputDecoration(
                    labelText: '推荐用量(可选)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () async {
                  final name = _addCtrl.text.trim();
                  if (name.isEmpty) return;
                  await db.addIngredient(widget.recipe.id!, name,
                      suggestQty: _qtyCtrl.text.trim().isEmpty ? null : _qtyCtrl.text.trim());
                  _addCtrl.clear();
                  _qtyCtrl.clear();
                  _refresh();
                },
                child: const Text('添加'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
