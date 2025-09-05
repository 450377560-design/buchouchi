import 'package:flutter/material.dart';
import '../db/database_helper.dart';

class TodayIngredientsPage extends StatefulWidget {
  const TodayIngredientsPage({super.key});

  @override
  State<TodayIngredientsPage> createState() => _TodayIngredientsPageState();
}

class _TodayIngredientsPageState extends State<TodayIngredientsPage> {
  final db = DatabaseHelper.instance;
  late Future<List<Map<String,String?>>> _future;

  @override
  void initState() {
    super.initState();
    _future = db.getTodayIngredientSummary();
  }

  Future<void> _refresh() async {
    setState(() => _future = db.getTodayIngredientSummary());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('今日食材清单（去重后）')),
      body: FutureBuilder<List<Map<String,String?>>>(
        future: _future,
        builder: (_, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final list = snap.data!;
          if (list.isEmpty) return const Center(child: Text('清单为空'));
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 0),
              itemBuilder: (_, i) {
                final m = list[i];
                final name = m['name']!;
                final suggest = m['suggest'];
                final user = m['user'];
                final ctrl = TextEditingController(text: user ?? '');
                return ListTile(
                  title: Text(name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (suggest != null && suggest.trim().isNotEmpty)
                        Text('推荐用量：$suggest', style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Text('自定义用量：', style: TextStyle(fontSize: 12)),
                          Expanded(
                            child: TextField(
                              controller: ctrl,
                              decoration: const InputDecoration(
                                hintText: '如：500g / 2把 / 3个',
                                isDense: true,
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              ),
                              onSubmitted: (v) async {
                                await db.upsertTodayUserQty(name, v.trim().isEmpty ? null : v.trim());
                                if (mounted) _refresh();
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
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
