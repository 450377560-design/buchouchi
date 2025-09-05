import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../models/cuisine.dart';
import '../db/database_helper.dart';

class RecipeEditPage extends StatefulWidget {
  final Cuisine? defaultCuisine;
  const RecipeEditPage({super.key, this.defaultCuisine});

  @override
  State<RecipeEditPage> createState() => _RecipeEditPageState();
}

class _RecipeEditPageState extends State<RecipeEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _ings = TextEditingController();

  Cuisine _cuisine = Cuisine.custom;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _cuisine = widget.defaultCuisine ?? Cuisine.custom;
  }

  @override
  Widget build(BuildContext context) {
    final cuisines = [...CuisineX.eight, Cuisine.custom];

    return Scaffold(
      appBar: AppBar(title: const Text('新增菜谱')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: '菜谱名称',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? '请输入菜名' : null,
              ),
              const SizedBox(height: 16),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: '所属菜系',
                  border: OutlineInputBorder(),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<Cuisine>(
                    value: _cuisine,
                    items: cuisines.map((c) {
                      return DropdownMenuItem(
                        value: c,
                        child: Text(c.zh),
                      );
                    }).toList(),
                    onChanged: (c) => setState(() => _cuisine = c ?? _cuisine),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ings,
                decoration: const InputDecoration(
                  labelText: '初始原料（逗号分隔，可留空）',
                  hintText: '如：鸡胸肉, 花生米, 干辣椒',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save),
                label: Text(_saving ? '保存中...' : '保存'),
              )
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final helper = DatabaseHelper.instance;
      final recipe = Recipe(
        name: _name.text.trim(),
        cuisine: _cuisine,
        isCustom: true,
      );
      final ingList = _ings.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      await helper.addRecipe(recipe, initIngredients: ingList);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
