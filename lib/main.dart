import 'package:flutter/material.dart';
import 'db/database_helper.dart';
import 'pages/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 初始化并预置八大菜系样例
  await DatabaseHelper.instance.db;
  runApp(const BuchouChiApp());
}

class BuchouChiApp extends StatelessWidget {
  const BuchouChiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '不愁吃',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4CAF50)),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}
