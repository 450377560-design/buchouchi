import 'package:flutter/material.dart';
import '../models/cuisine.dart';
import 'recipe_list_page.dart';
import 'recipe_edit_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    final items = [...CuisineX.eight, Cuisine.custom];

    return Scaffold(
      appBar: AppBar(title: const Text('不愁吃')),
      body: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, childAspectRatio: 1.1, crossAxisSpacing: 10, mainAxisSpacing: 10,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) {
          final c = items[i];
          return InkWell(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => RecipeListPage(cuisine: c),
              )).then((_) => setState(() {}));
            },
            child: Card(
              elevation: 3,
              child: Center(
                child: Text(c.zh, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(
            builder: (_) => const RecipeEditPage(),
          ));
          setState(() {});
        },
        icon: const Icon(Icons.add),
        label: const Text('新增菜谱'),
      ),
    );
  }
}
