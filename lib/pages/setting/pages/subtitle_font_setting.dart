import 'dart:io';

import 'package:PiliPlus/common/widgets/button/icon_button.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/utils/font_utils.dart';
import 'package:PiliPlus/utils/path_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/subtitle_font_utils.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as path;

class SubtitleFontSettingPage extends StatefulWidget {
  const SubtitleFontSettingPage({super.key});

  @override
  State<SubtitleFontSettingPage> createState() =>
      _SubtitleFontSettingPageState();
}

class _SubtitleFontSettingPageState extends State<SubtitleFontSettingPage> {
  List<SubtitleFontFace> _fonts = const [];
  List<String> _systemDirectories = const [];
  bool _loading = true;
  String _selectedFont = Pref.subtitleFontFamily;

  @override
  void initState() {
    super.initState();
    _loadFonts();
  }

  Future<void> _loadFonts() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final systemFamilies = FontUtils.getFont().toList()..sort();
      final fonts = await SubtitleFontUtils.discoverFonts(
        systemFamilies: systemFamilies,
      );
      if (!mounted) return;
      setState(() {
        _fonts = fonts;
        _systemDirectories = SubtitleFontUtils.systemFontDirectories();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      SmartDialog.showToast('读取字体失败：$error');
    }
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
      final selectedFontIsInFile = _fonts.any(
        (font) => font.file?.path == file.path && font.family == _selectedFont,
      );
      if (selectedFontIsInFile) {
        _selectedFont = SubtitleFontUtils.defaultFontFamily;
        await GStorage.setting.put(
          SettingBoxKey.subtitleFontFamily,
          _selectedFont,
        );
        await PlPlayerController.instance?.setSubtitleFontFamily(
          _selectedFont,
        );
      }
      await SubtitleFontUtils.deleteFont(file);
      await PlPlayerController.instance?.reloadSubtitleFonts();
      await _loadFonts();
    } catch (error) {
      SmartDialog.showToast('删除字体失败：$error');
    }
  }

  Future<void> _selectFont(SubtitleFontFace font) async {
    if (_selectedFont == font.family) return;
    setState(() => _selectedFont = font.family);
    await GStorage.setting.put(SettingBoxKey.subtitleFontFamily, font.family);
    await PlPlayerController.instance?.setSubtitleFontFamily(font.family);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SimpleScaffold(
      appBar: AppBar(
        title: const Text('字幕字体'),
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
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '字幕默认字体',
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '仅影响字幕显示，与“样式设置”中的应用字体分开设置。ASS 字幕保留脚本样式，缺失字体时由 libass 使用此字体并搜索系统字体。',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 12),
                          const _FontDirectoryTile(
                            title: '应用内置字体文件夹',
                            directory: SubtitleFontUtils.bundledAssetDirectory,
                          ),
                          _FontDirectoryTile(
                            title: '应用字体文件夹',
                            directory: SubtitleFontUtils.directory.path,
                            canOpen: true,
                          ),
                          for (final directory in _systemDirectories)
                            _FontDirectoryTile(
                              title: '系统字体文件夹',
                              directory: directory,
                              canOpen:
                                  Platform.isWindows ||
                                  Platform.isLinux ||
                                  Platform.isMacOS,
                            ),
                          const Divider(height: 20),
                          Text(
                            '识别到的字体（${_fonts.length}）',
                            style: theme.textTheme.titleSmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_fonts.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: Text('未识别到字体')),
                    )
                  else
                    SliverList.builder(
                      itemCount: _fonts.length,
                      itemBuilder: (context, index) {
                        final font = _fonts[index];
                        final isBundled =
                            font.source == SubtitleFontSource.bundled;
                        final isSelected = _selectedFont == font.family;
                        return Column(
                          children: [
                            ListTile(
                              dense: true,
                              leading: Icon(
                                isSelected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : null,
                              ),
                              title: Text(
                                font.family ==
                                        SubtitleFontUtils.defaultFontFamily
                                    ? '${font.family}（梦源黑体）'
                                    : font.family,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${font.sourceLabel}${font.file == null ? '' : ' · ${path.basename(font.file!.path)}'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: isBundled || font.file == null
                                  ? null
                                  : iconButton(
                                      tooltip: '删除字体文件',
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () => _deleteFont(font.file!),
                                    ),
                              onTap: () => _selectFont(font),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(72, 0, 16, 10),
                              child: _FontPreview(font: font),
                            ),
                            const Divider(height: 1),
                          ],
                        );
                      },
                    ),
                ],
              ),
      ),
    );
  }
}

class _FontDirectoryTile extends StatelessWidget {
  const _FontDirectoryTile({
    required this.title,
    required this.directory,
    this.canOpen = false,
  });

  final String title;
  final String directory;
  final bool canOpen;

  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    contentPadding: EdgeInsets.zero,
    title: Text(title),
    subtitle: SelectableText(directory, maxLines: 2),
    trailing: canOpen
        ? iconButton(
            context: context,
            tooltip: '打开目录',
            icon: const Icon(Icons.folder_open_outlined),
            onPressed: () => PathUtils.openDir(directory),
          )
        : null,
  );
}

class _FontPreview extends StatefulWidget {
  const _FontPreview({required this.font});

  final SubtitleFontFace font;

  @override
  State<_FontPreview> createState() => _FontPreviewState();
}

class _FontPreviewState extends State<_FontPreview> {
  String? _previewFamily;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  @override
  void didUpdateWidget(covariant _FontPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.font.file?.path != widget.font.file?.path ||
        oldWidget.font.family != widget.font.family) {
      _previewFamily = null;
      _loadPreview();
    }
  }

  Future<void> _loadPreview() async {
    try {
      final family = await SubtitleFontUtils.loadPreviewFamily(widget.font);
      if (mounted) setState(() => _previewFamily = family);
    } catch (_) {
      if (mounted) setState(() => _previewFamily = widget.font.family);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        '字幕预览 Aa 0123 你好，世界。夢源黑體',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: _previewFamily,
          fontSize: 17,
          color: color,
        ),
      ),
    );
  }
}
