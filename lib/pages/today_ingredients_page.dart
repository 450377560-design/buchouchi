import 'package:flutter/material.dart';
import '../db/database_helper.dart';

class TodayIngredientsPage extends StatefulWidget {
  const TodayIngredientsPage({super.key});

  @override
  State<TodayIngredientsPage> createState() => _TodayIngredientsPageState();
}

class _TodayIngredientsPageState extends State<TodayIngredientsPage> {
  final db = DatabaseHelper.instance;
  late Future<List<Map<String, dynamic>>> _future;

  final _controllers = <String, TextEditingController>{};

  @override
  void initState() {
    super.initState();
    _future = db.getTodayIngredientSummary();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) { c.dispose(); }
    super.dispose();
  }

  Future<void> _refresh() async => setState(() => _future = db.getTodayIngredientSummary());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('今日食材清单（去重后）')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (_, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final list = snap.data!;
          if (list.isEmpty) return const Center(child: Text('暂无食材'));
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 0),
              itemBuilder: (_, i) {
                final row = list[i];
                final name = row['name'] as String;
                final suggest = row['suggest'] as String?;
                final user = row['user'] as String?;
                final owned = row['owned'] as bool? ?? false;

                _controllers.putIfAbsent(name, () => TextEditingController(text: user ?? ''));

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(name, style: const TextStyle(fontSize: 18))),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('已有'),
                              Checkbox(
                                value: owned,
                                onChanged: (v) async {
                                  await db.setTodayIngredientOwned(name, v ?? false);
                                  if (mounted) setState(() {});
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (suggest != null && suggest.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('推荐用量：$suggest', style: const TextStyle(color: Colors.grey)),
                        ),
                      Row(
                        children: [
                          const Text('自定义用量：'),
                          Expanded(
                            child: TextField(
                              controller: _controllers[name],
                              decoration: const InputDecoration(
                                hintText: '如：500g / 2把 / 3个',
                              ),
                              onChanged: (v) async {
                                await db.upsertTodayUserQty(name, v.trim().isEmpty ? null : v.trim());
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
