import 'dart:io';

import 'package:PiliPlus/common/widgets/button/icon_button.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/utils/path_utils.dart';
import 'package:PiliPlus/utils/subtitle_font_utils.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:material_ui/material_ui.dart';

class SubtitleFontSettingPage extends StatefulWidget {
  const SubtitleFontSettingPage({super.key});

  @override
  State<SubtitleFontSettingPage> createState() =>
      _SubtitleFontSettingPageState();
}

class _SubtitleFontSettingPageState extends State<SubtitleFontSettingPage> {
  List<File> _fonts = const [];

  @override
  void initState() {
    super.initState();
    _loadFonts();
  }

  Future<void> _loadFonts() async {
    final fonts = await SubtitleFontUtils.listFonts();
    if (mounted) setState(() => _fonts = fonts);
  }

  Future<void> _importFonts() async {
    try {
      SmartDialog.showLoading();
      final imported = await SubtitleFontUtils.importFonts();
      SmartDialog.dismiss();
      if (imported.isEmpty) return;
      await PlPlayerController.instance?.reloadSubtitleFonts();
      await _loadFonts();
      SmartDialog.showToast('已导入 ${imported.length} 个字体文件');
    } catch (error) {
      SmartDialog.dismiss();
      SmartDialog.showToast('导入字体失败：$error');
    }
  }

  Future<void> _deleteFont(File file) async {
    try {
      await SubtitleFontUtils.deleteFont(file);
      await PlPlayerController.instance?.reloadSubtitleFonts();
      await _loadFonts();
    } catch (error) {
      SmartDialog.showToast('删除字体失败：$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SimpleScaffold(
      appBar: AppBar(
        title: const Text('ASS 字幕字体'),
        actions: [
          iconButton(
            context: context,
            tooltip: '导入字体',
            icon: const Icon(Icons.add),
            onPressed: _importFonts,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            ListTile(
              title: const Text('字体目录'),
              subtitle: SelectableText(
                SubtitleFontUtils.directory.path,
                maxLines: 2,
              ),
              trailing: iconButton(
                context: context,
                tooltip: '打开目录',
                icon: const Icon(Icons.folder_open_outlined),
                onPressed: () => PathUtils.openDir(
                  SubtitleFontUtils.directory.path,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('libass 也会搜索系统字体；支持 TTF、OTF 和 TTC。'),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _fonts.isEmpty
                  ? const Center(child: Text('还没有导入字体'))
                  : ListView.builder(
                      itemCount: _fonts.length,
                      itemBuilder: (context, index) {
                        final file = _fonts[index];
                        return ListTile(
                          title: Text(file.uri.pathSegments.last),
                          trailing: iconButton(
                            tooltip: '删除字体',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _deleteFont(file),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
