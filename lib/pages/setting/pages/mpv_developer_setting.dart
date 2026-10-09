import 'dart:io';

import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/utils/mpv_config.dart';
import 'package:PiliPlus/utils/path_utils.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:material_ui/material_ui.dart';

class MpvDeveloperSettingsPage extends StatefulWidget {
  const MpvDeveloperSettingsPage({super.key});

  @override
  State<MpvDeveloperSettingsPage> createState() =>
      _MpvDeveloperSettingsPageState();
}

class _MpvDeveloperSettingsPageState extends State<MpvDeveloperSettingsPage> {
  final _mpvController = TextEditingController();
  final _inputController = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _showInputConfig = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await MpvConfig.ensureDirectory();
      final mpvFile = File(MpvConfig.mpvFilePath);
      final inputFile = File(MpvConfig.inputFilePath);
      if (await mpvFile.exists()) {
        _mpvController.text = await mpvFile.readAsString();
      }
      if (await inputFile.exists()) {
        _inputController.text = await inputFile.readAsString();
      }
    } catch (error) {
      SmartDialog.showToast('读取 MPV 配置失败：$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await MpvConfig.ensureDirectory();
      await File(MpvConfig.mpvFilePath).writeAsString(
        _mpvController.text,
        flush: true,
      );
      await File(MpvConfig.inputFilePath).writeAsString(
        _inputController.text,
        flush: true,
      );
      SmartDialog.showToast('配置已保存，下次开始播放时生效');
    } catch (error) {
      SmartDialog.showToast('保存 MPV 配置失败：$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _mpvController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _showInputConfig ? _inputController : _mpvController;
    final fileName = _showInputConfig
        ? MpvConfig.inputFileName
        : MpvConfig.mpvFileName;
    final filePath = _showInputConfig
        ? MpvConfig.inputFilePath
        : MpvConfig.mpvFilePath;
    return SimpleScaffold(
      appBar: AppBar(
        title: const Text('MPV 高级配置'),
        actions: [
          IconButton(
            tooltip: '打开配置文件夹',
            onPressed:
                Platform.isWindows || Platform.isMacOS || Platform.isLinux
                ? () => PathUtils.openDir(MpvConfig.directoryPath)
                : null,
            icon: const Icon(Icons.folder_open_outlined),
          ),
          IconButton(
            tooltip: '保存配置',
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('mpv.conf'),
                          selected: !_showInputConfig,
                          onSelected: (_) =>
                              setState(() => _showInputConfig = false),
                        ),
                        ChoiceChip(
                          label: const Text('input.conf'),
                          selected: _showInputConfig,
                          onSelected: (_) =>
                              setState(() => _showInputConfig = true),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      filePath,
                      maxLines: 2,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '高级配置会覆盖部分应用播放器选项。配置在创建播放器时读取；保存后重启应用生效。',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: TextField(
                        key: ValueKey(fileName),
                        controller: controller,
                        expands: true,
                        minLines: null,
                        maxLines: null,
                        textAlignVertical: TextAlignVertical.top,
                        keyboardType: TextInputType.multiline,
                        autocorrect: false,
                        enableSuggestions: false,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          hintText: _showInputConfig
                              ? '例如：\nSPACE cycle pause\nLEFT seek -5'
                              : '例如：\nprofile=gpu-hq\ninterpolation=yes',
                          border: const OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: controller.clear,
                        icon: const Icon(Icons.delete_outline),
                        label: Text('清空 $fileName'),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
