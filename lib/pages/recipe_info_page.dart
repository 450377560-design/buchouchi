import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';

import '../models/recipe.dart';
import '../models/cuisine.dart';
import '../db/database_helper.dart';
import '../services/asset_image_resolver.dart';
import 'recipe_detail_page.dart';

class RecipeInfoPage extends StatefulWidget {
  final Recipe recipe;
  const RecipeInfoPage({super.key, required this.recipe});

  @override
  State<RecipeInfoPage> createState() => _RecipeInfoPageState();
}

class _RecipeInfoPageState extends State<RecipeInfoPage> {
  String? _assetPath; // 本地 assets 映射
  String? _filePath;  // 私有目录文件
  String? _netUrl;    // 网络兜底
  final db = DatabaseHelper.instance;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final r = widget.recipe;

    // 1) assets 映射
    final a = await AssetImageResolver.instance.assetFor(r.name);
    if (mounted) setState(() => _assetPath = a);

    // 2) DB 中的 image_url（可能是 file:// 或绝对路径或 http/https）
    final stored = await db.getRecipeImage(r.id!);
    if (stored != null && stored.isNotEmpty) {
      if (stored.startsWith('file://')) {
        if (mounted) setState(() => _filePath = Uri.parse(stored).toFilePath());
      } else if (stored.startsWith('/')) {
        if (mounted) setState(() => _filePath = stored);
      } else if (stored.startsWith('http')) {
        if (mounted) setState(() => _netUrl = stored);
      }
    }

    // 3) 若无本地 & 无网络缓存，则尝试旧逻辑的网络兜底（可选）
    if (_assetPath == null && _filePath == null && _netUrl == null) {
      final url = await db.resolveAndCacheImage(r.id!, r.name);
      if (mounted) setState(() => _netUrl = url);
    }
  }

  Future<void> _pickFromGallery() async {
    final r = widget.recipe;
    try {
      final picker = ImagePicker();
      final x = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1600);
      if (x == null) return;

      // 拷贝到 App 私有目录，避免外部图片被用户移动/删除后失效
      final dir = await getApplicationDocumentsDirectory();
      final ext = p.extension(x.path).toLowerCase();
      final filename = 'recipe_${r.id}_${DateTime.now().millisecondsSinceEpoch}$ext';
      final dest = p.join(dir.path, filename);

      await File(x.path).copy(dest);
      final asUri = 'file://$dest';

      await db.setRecipeImage(r.id!, asUri);
      if (mounted) {
        setState(() {
          _filePath = dest;
          _netUrl = null; // 强制优先走本地
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已从相册设置图片')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('设置图片失败：$e')),
      );
    }
  }

  Future<void> _clearImage() async {
    await db.setRecipeImage(widget.recipe.id!, null);
    if (mounted) {
      setState(() {
        _filePath = null;
        // 不改 _assetPath，仍可显示 assets 映射；若也没有则回退网络/占位
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已清除自定义图片')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.recipe;
    final text = (r.instructions?.trim().isNotEmpty ?? false)
        ? r.instructions!.trim() : '暂无做法，稍后补充～';

    Widget img;
    if (_assetPath != null) {
      img = Image.asset(_assetPath!, fit: BoxFit.cover);
    } else if (_filePath != null && File(_filePath!).existsSync()) {
      img = Image.file(File(_filePath!), fit: BoxFit.cover);
    } else if (_netUrl != null) {
      img = Image.network(_netUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder());
    } else {
      img = _placeholder();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(r.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'pick') _pickFromGallery();
              if (v == 'clear') _clearImage();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'pick', child: Text('从相册选择图片')),
              const PopupMenuItem(value: 'clear', child: Text('清除图片')),
            ],
          )
        ],
      ),
      body: ListView(
        children: [
          AspectRatio(aspectRatio: 16 / 9, child: img),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(spacing: 8, runSpacing: 8, children: [
                  Chip(label: Text(r.cuisine.zh)),
                  if (r.isCustom) const Chip(label: Text('自定义')),
                ]),
                const SizedBox(height: 12),
                const Text('烹饪方法', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SelectableText(text),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => RecipeDetailPage(recipe: r))),
                  icon: const Icon(Icons.list_alt),
                  label: const Text('查看/勾选原料清单'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () async {
                    await db.toggleToday(r.id!, setTo: null);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('已切换 “${r.name}” 的今日食谱状态')),
                      );
                    }
                  },
                  icon: const Icon(Icons.today),
                  label: const Text('加入/移除 今日食谱'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _pickFromGallery,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('从相册选择图片'),
                ),
                const SizedBox(height: 6),
                TextButton.icon(
                  onPressed: _clearImage,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('清除图片'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        child: const Text('暂无图片'),
      );
}
