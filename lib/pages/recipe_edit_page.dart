import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../db/database_helper.dart';
import '../models/cuisine.dart';
import '../models/recipe.dart';

class RecipeEditPage extends StatefulWidget {
  /// 传入 recipe 为编辑，不传则为新建
  final Recipe? recipe;
  const RecipeEditPage({super.key, this.recipe});

  @override
  State<RecipeEditPage> createState() => _RecipeEditPageState();
}

class _RecipeEditPageState extends State<RecipeEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _instCtrl = TextEditingController();

  late Cuisine _cuisine;
  bool _saving = false;

  // 图片相关
  String? _storedImage;     // 当前 DB 中的 image_url（file:// 或 http）
  String? _pickedFilePath;  // 本次从相册选择后，复制到私有目录的绝对路径
  bool _clearRequested = false; // 用户选择“清除图片”

  final db = DatabaseHelper.instance;

  @override
  void initState() {
    super.initState();
    final r = widget.recipe;
    if (r != null) {
      _nameCtrl.text = r.name;
      _instCtrl.text = (r.instructions ?? '').trim();
      _cuisine = r.cuisine;
      _loadStoredImage(r.id!);
    } else {
      _cuisine = Cuisine.chuancai;
      _instCtrl.text = _defaultStepsPreview();
    }
  }

  Future<void> _loadStoredImage(int recipeId) async {
    final v = await db.getRecipeImage(recipeId);
    if (!mounted) return;
    setState(() => _storedImage = v);
  }

  String _defaultStepsPreview() => '''
1) 准备好食材并完成基础处理；
2) 热锅冷油依次下主辅料；
3) 调味后根据口感收汁或焖煮；
4) 出锅装盘，即成《${_nameCtrl.text.isEmpty ? '此菜' : _nameCtrl.text}》。
'''.trim();

  Future<void> _pickFromGallery() async {
    try {
      final picker = ImagePicker();
      final x = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1600);
      if (x == null) return;

      // 拷贝到 App 私有目录
      final dir = await getApplicationDocumentsDirectory();
      final ext = p.extension(x.path).toLowerCase();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'recipe_${widget.recipe?.id ?? 'new'}_$stamp$ext';
      final dest = p.join(dir.path, fileName);
      await File(x.path).copy(dest);

      setState(() {
        _pickedFilePath = dest;
        _clearRequested = false; // 覆盖清除状态
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已从相册选择图片')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('选择图片失败：$e')),
      );
    }
  }

  void _clearImage() {
    setState(() {
      _pickedFilePath = null;
      _clearRequested = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('保存后将清除图片')),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    try {
      final name = _nameCtrl.text.trim();
      final instructions = _instCtrl.text.trim().isEmpty ? null : _instCtrl.text.trim();

      if (widget.recipe == null) {
        // 新建
        final newRecipe = Recipe(
          id: null,
          name: name,
          cuisine: _cuisine,
          isCustom: true,
          imageUrl: null,
          instructions: instructions,
        );

        final newId = await db.addRecipe(newRecipe);
        // 处理图片：若选择了图片，落库 file://path
        if (_pickedFilePath != null && File(_pickedFilePath!).existsSync()) {
          await db.setRecipeImage(newId, 'file://${_pickedFilePath!}');
        }
      } else {
        // 编辑：更新基本信息
        final d = await db.db;
        await d.update('recipes', {
          'name': name,
          'cuisine': _cuisine.key,
          'instructions': instructions,
          // is_custom 保持不改；如果想允许切换，这里可加开关
        }, where: 'id = ?', whereArgs: [widget.recipe!.id]);

        // 处理图片
        if (_clearRequested) {
          await db.setRecipeImage(widget.recipe!.id!, null);
        } else if (_pickedFilePath != null && File(_pickedFilePath!).existsSync()) {
          await db.setRecipeImage(widget.recipe!.id!, 'file://${_pickedFilePath!}');
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop(true); // 返回上一页并标记成功
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildPreviewImage() {
    // 优先显示：本次新选图 -> 已存 file:// -> (可选) 网络 -> 占位
    if (_pickedFilePath != null && File(_pickedFilePath!).existsSync()) {
      return Image.file(File(_pickedFilePath!), fit: BoxFit.cover);
    }
    if (!_clearRequested && _storedImage != null && _storedImage!.isNotEmpty) {
      if (_storedImage!.startsWith('file://')) {
        final path = Uri.parse(_storedImage!).toFilePath();
        if (File(path).existsSync()) {
          return Image.file(File(path), fit: BoxFit.cover);
        }
      } else if (_storedImage!.startsWith('/')) {
        if (File(_storedImage!).existsSync()) {
          return Image.file(File(_storedImage!), fit: BoxFit.cover);
        }
      } else if (_storedImage!.startsWith('http')) {
        return Image.network(_storedImage!, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _placeholder());
      }
    }
    return _placeholder();
  }

  Widget _placeholder() => Container(
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        child: const Text('暂无图片'),
      );

  @override
  void dispose() {
    _nameCtrl.dispose();
    _instCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.recipe != null;
    final title = isEdit ? '编辑菜谱' : '新建菜谱';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'pick') _pickFromGallery();
              if (v == 'clear') _clearImage();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'pick', child: Text('从相册选择图片')),
              const PopupMenuItem(value: 'clear', child: Text('清除图片')),
            ],
          ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _saving,
        child: ListView(
          children: [
            AspectRatio(aspectRatio: 16 / 9, child: _buildPreviewImage()),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: '菜名',
                        hintText: '请输入菜名（必填）',
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (v) => (v == null || v.trim().isEmpty) ? '请填写菜名' : null,
                      onChanged: (_) {
                        if (_instCtrl.text.trim().isEmpty) setState((){});
                      },
                    ),
                    const SizedBox(height: 12),
                    InputDecorator(
                      decoration: const InputDecoration(labelText: '菜系'),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<Cuisine>(
                          isExpanded: true,
                          value: _cuisine,
                          onChanged: (c) => setState(() => _cuisine = c!),
                          items: Cuisine.values.map((c) {
                            return DropdownMenuItem(
                              value: c,
                              child: Text(c.zh),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _instCtrl,
                      minLines: 4,
                      maxLines: 10,
                      decoration: const InputDecoration(
                        labelText: '烹饪方法',
                        hintText: '可填写步骤说明；留空则使用默认模板',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        FilledButton.icon(
                          onPressed: _pickFromGallery,
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('从相册选择图片'),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: _clearImage,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('清除图片'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        child: Text(_saving ? '保存中...' : '保存'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (!isEdit)
                      const Text(
                        '提示：配料请保存后在“原料清单”页添加/删除。',
                        style: TextStyle(color: Colors.grey),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
