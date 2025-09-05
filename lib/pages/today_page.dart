import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/recipe.dart';
import '../models/cuisine.dart';
import 'recipe_info_page.dart';
import 'today_ingredients_page.dart';

class TodayPage extends StatefulWidget {
  const TodayPage({super.key});
  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  final db = DatabaseHelper.instance;
  late Future<List<Recipe>> _future;

  @override
  void initState() {
    super.initState();
    _future = db.getTodayRecipes();
  }

  Future<void> _refresh() async => setState(() => _future = db.getTodayRecipes());

  String _shortDate(String iso) => iso.substring(0, 10); // yyyy-MM-dd

  @override
  Widget build(BuildContext context) {
    final dt = _shortDate(db.today);
    return Scaffold(
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text('今日食谱（$dt）'),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.push(context,
                MaterialPageRoute(builder: (_) => const TodayIngredientsPage()));
            },
            icon: const Icon(Icons.shopping_bag_outlined, color: Colors.green),
            label: const Text('食材清单', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
      body: FutureBuilder<List<Recipe>>(
        future: _future,
        builder: (_, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final list = snap.data!;
          if (list.isEmpty) return const Center(child: Text('还没有添加今日菜谱，去各菜系页勾选吧～'));
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 0),
              itemBuilder: (_, i) {
                final r = list[i];
                return ListTile(
                  title: Text(r.name, style: const TextStyle(fontSize: 18)),
                  subtitle: Text(r.cuisine.zh),
                  onTap: () {
                    Navigator.push(context,
                      MaterialPageRoute(builder: (_) => RecipeInfoPage(recipe: r)));
                  },
                  trailing: IconButton(
                    tooltip: '从今日移除',
                    icon: const Icon(Icons.remove_circle_outlined),
                    onPressed: () async {
                      await db.toggleToday(r.id!, setTo: false);
                      _refresh();
                    },
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
