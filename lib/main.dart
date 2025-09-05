import 'package:flutter/material.dart';
import 'db/database_helper.dart';
import 'pages/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.instance.db; // 初始化/升级数据库
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
