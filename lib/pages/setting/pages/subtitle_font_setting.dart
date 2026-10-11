import 'dart:io';

import 'package:PiliPlus/common/widgets/button/icon_button.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/models/common/video/subtitle_pref_type.dart';
import 'package:PiliPlus/plugin/pl_player/controller.dart';
import 'package:PiliPlus/pages/setting/widgets/ordered_multi_select_dialog.dart';
import 'package:PiliPlus/pages/setting/widgets/select_dialog.dart';
import 'package:PiliPlus/utils/font_utils.dart';
import 'package:PiliPlus/utils/path_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/subtitle_font_utils.dart';
import 'package:file_picker/file_picker.dart';
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
  String _activeFontDirectory = SubtitleFontUtils.directoryPath;
  bool _loading = true;
  String _selectedFont = Pref.subtitleFontFamily;
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  String _searchText = '';

  List<SubtitleFontFace> get _visibleFonts {
    final query = _searchText.trim().toLowerCase();
    if (query.isEmpty) return _fonts;
    return _fonts.where((font) {
      final fileName = font.file == null ? '' : path.basename(font.file!.path);
      return font.family.toLowerCase().contains(query) ||
          fileName.toLowerCase().contains(query) ||
          font.sourceLabel.toLowerCase().contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadFonts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadFonts() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final activeDirectory = await SubtitleFontUtils.ensureDirectory();
      final systemFamilies = FontUtils.getFont().toList()..sort();
      final fonts = await SubtitleFontUtils.discoverFonts(
        systemFamilies: systemFamilies,
      );
      if (!mounted) return;
      setState(() {
        _fonts = fonts;
        _systemDirectories = SubtitleFontUtils.systemFontDirectories();
        _activeFontDirectory = activeDirectory.path;
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

  Future<void> _chooseFontDirectory() async {
    final previousDirectory = SubtitleFontUtils.directoryPath;
    try {
      final selectedDirectory = await FilePicker.getDirectoryPath(
        initialDirectory: Directory(previousDirectory).existsSync()
            ? previousDirectory
            : null,
      );
      if (selectedDirectory == null || !mounted) return;
      final normalizedSelection = path.normalize(
        path.absolute(selectedDirectory),
      );
      if (SubtitleFontUtils.sameDirectory(
        normalizedSelection,
        previousDirectory,
      )) {
        return;
      }

      await SubtitleFontUtils.setDirectory(normalizedSelection);
      try {
        await SubtitleFontUtils.ensureDirectory();
      } catch (_) {
        await SubtitleFontUtils.setDirectory(previousDirectory);
        rethrow;
      }
      await PlPlayerController.instance?.reloadSubtitleFonts();
      await SubtitleFontUtils.removeDuplicateBundledFontFromDefaultDirectory();
      await _loadFonts();
      SmartDialog.showToast('字体文件夹已更新');
    } catch (error) {
      SmartDialog.showToast('设置字体文件夹失败：$error');
    }
  }

  Future<void> _resetFontDirectory() async {
    final previousDirectory = SubtitleFontUtils.directoryPath;
    try {
      await SubtitleFontUtils.setDirectory(null);
      try {
        await SubtitleFontUtils.ensureDirectory();
      } catch (_) {
        await SubtitleFontUtils.setDirectory(previousDirectory);
        rethrow;
      }
      await PlPlayerController.instance?.reloadSubtitleFonts();
      await _loadFonts();
      SmartDialog.showToast('已使用应用默认字体文件夹');
    } catch (error) {
      SmartDialog.showToast('重置字体文件夹失败：$error');
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

  Future<void> _selectLanguageFont(String languageTag) async {
    final current = Pref.subtitleFontLanguageMap[languageTag] ?? '';
    final families = _fonts.map((font) => font.family).toSet();
    if (current.isNotEmpty) families.add(current);
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => SelectDialog<String>(
        title: '${SubtitleFontUtils.languageLabel(languageTag)} 字体',
        value: current,
        values: [
          ('', '使用默认字体（${Pref.subtitleFontFamily}）'),
          ...families.map((family) => (family, family)),
        ],
      ),
    );
    if (selected == null) return;
    final mapping = Map<String, String>.from(Pref.subtitleFontLanguageMap);
    if (selected.isEmpty) {
      mapping.remove(languageTag);
    } else {
      mapping[languageTag] = selected;
    }
    await GStorage.setting.put(SettingBoxKey.subtitleFontLanguageMap, mapping);
    if (mounted) setState(() {});
  }

  Future<String?> _promptLanguageTag() async {
    var input = '';
    String? errorText;
    return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('添加字幕语言'),
          content: TextField(
            autofocus: true,
            onChanged: (value) => input = value,
            decoration: InputDecoration(
              labelText: 'BCP 47 语言标签',
              hintText: '例如 pt-BR、zh-Hant-TW、en',
              errorText: errorText,
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final normalized = SubtitleFontUtils.normalizeLanguageTag(
                  input,
                );
                if (normalized == null) {
                  setDialogState(() => errorText = '请输入有效的 BCP 47 语言标签');
                } else {
                  Navigator.of(context).pop(normalized);
                }
              },
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addCustomLanguageTag() async {
    final tag = await _promptLanguageTag();
    if (tag == null) return;
    if (SubtitleFontUtils.commonLanguageOptions.containsKey(tag)) {
      SmartDialog.showToast('该语言已在常用列表中');
      return;
    }
    final tags = Pref.subtitleCustomLanguageTags.toSet()..add(tag);
    await GStorage.setting.put(
      SettingBoxKey.subtitleCustomLanguageTags,
      tags.toList()..sort(),
    );
    if (mounted) setState(() {});
  }

  Future<void> _removeCustomLanguageTag(String tag) async {
    final tags = Pref.subtitleCustomLanguageTags.toSet()..remove(tag);
    final mapping = Map<String, String>.from(Pref.subtitleFontLanguageMap)
      ..remove(tag);
    final preferences = Pref.subtitleLanguagePreferences
        .where((item) => item != tag)
        .toList();
    await GStorage.setting.put(
      SettingBoxKey.subtitleCustomLanguageTags,
      tags.toList(),
    );
    await GStorage.setting.put(
      SettingBoxKey.subtitleFontLanguageMap,
      mapping,
    );
    await GStorage.setting.put(
      SettingBoxKey.subtitleLanguagePreferences,
      preferences,
    );
    if (mounted) setState(() {});
  }

  Future<void> _selectPreferredLanguages() async {
    final options = <String, String>{
      ...SubtitleFontUtils.commonLanguageOptions,
      for (final tag in Pref.subtitleCustomLanguageTags)
        if (!SubtitleFontUtils.commonLanguageOptions.containsKey(tag))
          tag: '$tag（自定义）',
    };
    final selected = await showDialog<List<String>>(
      context: context,
      builder: (context) => OrderedMultiSelectDialog<String>(
        title: const Text('首选字幕语言（按顺序）'),
        initValues: Pref.subtitleLanguagePreferences.where(options.containsKey),
        values: options,
      ),
    );
    if (selected == null) return;
    await GStorage.setting.put(
      SettingBoxKey.subtitleLanguagePreferences,
      selected,
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SimpleScaffold(
      appBar: AppBar(
        title: const Text('字幕'),
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
            : Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                child: CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '字幕自动选择',
                              style: theme.textTheme.titleSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '选择自动启用的字幕轨道',
                              style: theme.textTheme.bodySmall,
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(
                                Icons.closed_caption_outlined,
                              ),
                              title: const Text('自动启用策略'),
                              subtitle: Text(Pref.subtitlePreferenceV2.desc),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _selectSubtitlePreference(),
                            ),
                            const Divider(height: 24),
                            Text(
                              '字幕语言偏好与字体',
                              style: theme.textTheme.titleSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '可按语言优先级自动选择字幕，并为每种语言指定字体。自定义语言标签遵循 BCP 47。',
                              style: theme.textTheme.bodySmall,
                            ),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.sort_by_alpha),
                              title: const Text('首选字幕语言'),
                              subtitle: Text(
                                Pref.subtitleLanguagePreferences.isEmpty
                                    ? '未设置，沿用字幕列表顺序'
                                    : Pref.subtitleLanguagePreferences
                                          .map(SubtitleFontUtils.languageLabel)
                                          .join(' → '),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: _selectPreferredLanguages,
                            ),
                            const SizedBox(height: 4),
                            Text('各语言字体', style: theme.textTheme.titleSmall),
                            for (final entry in <String, String>{
                              ...SubtitleFontUtils.commonLanguageOptions,
                              for (final tag in Pref.subtitleCustomLanguageTags)
                                if (!SubtitleFontUtils.commonLanguageOptions
                                    .containsKey(tag))
                                  tag: '$tag（自定义）',
                            }.entries)
                              ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(entry.value),
                                subtitle: Text(
                                  '${entry.key} · ${Pref.subtitleFontLanguageMap[entry.key] ?? '使用默认字体：${Pref.subtitleFontFamily}'}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing:
                                    Pref.subtitleCustomLanguageTags.contains(
                                      entry.key,
                                    )
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.chevron_right),
                                          IconButton(
                                            tooltip: '移除自定义语言',
                                            icon: const Icon(
                                              Icons.delete_outline,
                                            ),
                                            onPressed: () =>
                                                _removeCustomLanguageTag(
                                                  entry.key,
                                                ),
                                          ),
                                        ],
                                      )
                                    : const Icon(Icons.chevron_right),
                                onTap: () => _selectLanguageFont(entry.key),
                              ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: _addCustomLanguageTag,
                                icon: const Icon(Icons.add),
                                label: const Text('添加自定义语言标签'),
                              ),
                            ),
                            const Divider(height: 24),
                            Text(
                              '默认字幕字体',
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
                              directory:
                                  SubtitleFontUtils.bundledAssetDirectory,
                            ),
                            _FontDirectoryTile(
                              title:
                                  SubtitleFontUtils.sameDirectory(
                                    _activeFontDirectory,
                                    SubtitleFontUtils.directoryPath,
                                  )
                                  ? '字幕字体文件夹'
                                  : '字幕字体文件夹（所选位置不可用，当前使用备用位置）',
                              directory: _activeFontDirectory,
                              canOpen: true,
                              onChoose: _chooseFontDirectory,
                              onReset: _resetFontDirectory,
                              canReset: !SubtitleFontUtils.sameDirectory(
                                SubtitleFontUtils.directoryPath,
                                SubtitleFontUtils.defaultDirectoryPath,
                              ),
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
                            TextField(
                              controller: _searchController,
                              onChanged: (value) => setState(
                                () => _searchText = value,
                              ),
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.search),
                                hintText: '搜索文件名、字体名称或家族名',
                                suffixIcon: _searchText.isEmpty
                                    ? null
                                    : IconButton(
                                        tooltip: '清除搜索',
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() => _searchText = '');
                                        },
                                        icon: const Icon(Icons.clear),
                                      ),
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '字体（${_visibleFonts.length}/${_fonts.length}）',
                              style: theme.textTheme.titleSmall,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_visibleFonts.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Text(
                            _fonts.isEmpty ? '未识别到字体' : '没有匹配的字体',
                          ),
                        ),
                      )
                    else
                      SliverList.builder(
                        itemCount: _visibleFonts.length,
                        itemBuilder: (context, index) {
                          final font = _visibleFonts[index];
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
                                        onPressed: () =>
                                            _deleteFont(font.file!),
                                      ),
                                onTap: () => _selectFont(font),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  72,
                                  0,
                                  16,
                                  10,
                                ),
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
      ),
    );
  }

  Future<void> _selectSubtitlePreference() async {
    final selected = await showDialog<SubtitlePrefType>(
      context: context,
      builder: (context) => SelectDialog<SubtitlePrefType>(
        title: '字幕选择偏好',
        value: Pref.subtitlePreferenceV2,
        values: SubtitlePrefType.values
            .map((item) => (item, item.desc))
            .toList(),
      ),
    );
    if (selected == null) return;
    await GStorage.setting.put(
      SettingBoxKey.subtitlePreferenceV2,
      selected.index,
    );
    if (mounted) setState(() {});
  }
}

class _FontDirectoryTile extends StatelessWidget {
  const _FontDirectoryTile({
    required this.title,
    required this.directory,
    this.canOpen = false,
    this.onChoose,
    this.onReset,
    this.canReset = false,
  });

  final String title;
  final String directory;
  final bool canOpen;
  final VoidCallback? onChoose;
  final VoidCallback? onReset;
  final bool canReset;

  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    contentPadding: EdgeInsets.zero,
    title: Text(title),
    subtitle: SelectableText(directory, maxLines: 2),
    trailing: canOpen
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onChoose != null) ...[
                iconButton(
                  context: context,
                  tooltip: '选择字体文件夹',
                  icon: const Icon(Icons.drive_file_move_outline),
                  onPressed: onChoose,
                ),
                const SizedBox(width: 8),
              ],
              iconButton(
                context: context,
                tooltip: '打开目录',
                icon: const Icon(Icons.folder_open_outlined),
                onPressed:
                    Platform.isWindows || Platform.isMacOS || Platform.isLinux
                    ? () => PathUtils.openDir(directory)
                    : null,
              ),
              if (canReset) const SizedBox(width: 8),
              if (canReset)
                iconButton(
                  context: context,
                  tooltip: '恢复默认文件夹',
                  icon: const Icon(Icons.restore),
                  onPressed: onReset,
                ),
            ],
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
        'ABCDEFGHIJKLMNOPQRSTUVWXYZ\n'
        'abcdefghijklmnopqrstuvwxyz\n'
        '0123456789\n'
        '全角：，。！？；：（）【】《》「」『』、…—　\n'
        '半角: ,.!?;:()[]{}<>\"\'/-_+@#%&*\n'
        '中文：春风拂过街道，少年抬头看向远方。\n'
        'English: The quick brown fox jumps over the lazy dog.\n'
        '日本語：静かな夜に、星空を見上げて歩く。',
        style: TextStyle(
          fontFamily: _previewFamily,
          fontSize: 15,
          color: color,
        ),
      ),
    );
  }
}
