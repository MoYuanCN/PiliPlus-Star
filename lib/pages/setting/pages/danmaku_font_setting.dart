import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/utils/font_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/subtitle_font_utils.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as path;

class DanmakuFontSettingPage extends StatefulWidget {
  const DanmakuFontSettingPage({super.key});

  @override
  State<DanmakuFontSettingPage> createState() => _DanmakuFontSettingPageState();
}

class _DanmakuFontSettingPageState extends State<DanmakuFontSettingPage> {
  List<SubtitleFontFace> _fonts = const [];
  bool _loading = true;
  String _selectedFont = Pref.danmakuFontFamily;
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
    try {
      await SubtitleFontUtils.ensureDirectory();
      final systemFamilies = FontUtils.getFont().toList()..sort();
      final fonts = await SubtitleFontUtils.discoverFonts(
        systemFamilies: systemFamilies,
      );
      if (!mounted) return;
      setState(() {
        _fonts = fonts;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectFont(String family) async {
    if (_selectedFont == family) return;
    await GStorage.setting.put(SettingBoxKey.danmakuFontFamily, family);
    if (mounted) setState(() => _selectedFont = family);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SimpleScaffold(
      appBar: AppBar(title: const Text('弹幕字体')),
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
                              '当前字体：${_selectedFont.isEmpty ? '默认' : _selectedFont}',
                              style: theme.textTheme.titleSmall,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '可以从应用字体文件夹和系统字体中选择。',
                              style: theme.textTheme.bodySmall,
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _searchController,
                              onChanged: (value) =>
                                  setState(() => _searchText = value),
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
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          ListTile(
                            dense: true,
                            leading: Icon(
                              _selectedFont.isEmpty
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              color: _selectedFont.isEmpty
                                  ? theme.colorScheme.primary
                                  : null,
                            ),
                            title: const Text('默认弹幕字体'),
                            subtitle: const Text('使用应用默认字体'),
                            onTap: () => _selectFont(''),
                          ),
                          const Divider(height: 1),
                        ],
                      ),
                    ),
                    if (_visibleFonts.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Text(_fonts.isEmpty ? '未识别到字体' : '没有匹配的字体'),
                        ),
                      )
                    else
                      SliverList.builder(
                        itemCount: _visibleFonts.length,
                        itemBuilder: (context, index) {
                          final font = _visibleFonts[index];
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
                                onTap: () => _selectFont(font.family),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  72,
                                  0,
                                  16,
                                  10,
                                ),
                                child: _DanmakuFontPreview(font: font),
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
}

class _DanmakuFontPreview extends StatefulWidget {
  const _DanmakuFontPreview({required this.font});

  final SubtitleFontFace font;

  @override
  State<_DanmakuFontPreview> createState() => _DanmakuFontPreviewState();
}

class _DanmakuFontPreviewState extends State<_DanmakuFontPreview> {
  String? _previewFamily;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  @override
  void didUpdateWidget(covariant _DanmakuFontPreview oldWidget) {
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
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Text(
      'ABCDEFGHIJKLMNOPQRSTUVWXYZ\n'
      'abcdefghijklmnopqrstuvwxyz\n'
      '0123456789\n'
      '全角：，。！？；：（）【】《》「」『』、…—　\n'
      '半角: ,.!?;:()[]{}<>"\'/-_+@#%&*\n'
      '中文：春风拂过街道，少年抬头看向远方。\n'
      'English: The quick brown fox jumps over the lazy dog.\n'
      '日本語：静かな夜に、星空を見上げて歩く。',
      style: TextStyle(
        fontFamily: _previewFamily,
        fontSize: 13,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}
