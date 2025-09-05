import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/recipe.dart';
import 'today_ingredients_page.dart';
import '../models/cuisine.dart';


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

  Future<void> _refresh() async {
    setState(() => _future = db.getTodayRecipes());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('今日食谱（${DatabaseHelper.instance.today}）'),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => const TodayIngredientsPage(),
              ));
            },
            icon: const Icon(Icons.shopping_bag_outlined),
            label: const Text('食材清单'),
          ),
        ],
      ),
      body: FutureBuilder<List<Recipe>>(
        future: _future,
        builder: (_, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final list = snap.data!;
          if (list.isEmpty) return const Center(child: Text('还没有勾选任何菜谱，去菜谱页点一下“今日食谱”吧～'));
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
                  trailing: IconButton(
                    tooltip: '移出今日食谱',
                    icon: const Icon(Icons.remove_circle_outline),
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
