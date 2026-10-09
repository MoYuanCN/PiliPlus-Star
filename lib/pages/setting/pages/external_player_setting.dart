import 'dart:async';
import 'dart:io';

import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/utils/external_player.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:material_ui/material_ui.dart';

class ExternalPlayerSettingsPage extends StatefulWidget {
  const ExternalPlayerSettingsPage({super.key});

  @override
  State<ExternalPlayerSettingsPage> createState() =>
      _ExternalPlayerSettingsPageState();
}

class _ExternalPlayerSettingsPageState
    extends State<ExternalPlayerSettingsPage> {
  late String _type = Pref.externalPlayerType;
  late final _mpvPathController = TextEditingController(
    text: Pref.externalPlayerMpvPath,
  );
  late final _mpvArgumentsController = TextEditingController(
    text: Pref.externalPlayerMpvArguments,
  );
  late final _potPlayerPathController = TextEditingController(
    text: Pref.externalPlayerPotPlayerPath,
  );
  late final _potPlayerArgumentsController = TextEditingController(
    text: Pref.externalPlayerPotPlayerArguments,
  );
  late final _customPathController = TextEditingController(
    text: Pref.externalPlayerPath,
  );
  late final _customArgumentsController = TextEditingController(
    text: Pref.externalPlayerArguments,
  );
  Map<String, String> _detectedPlayers = const {};

  TextEditingController get _pathController => switch (_type) {
    'potplayer' => _potPlayerPathController,
    'custom' => _customPathController,
    _ => _mpvPathController,
  };

  TextEditingController get _argumentsController => switch (_type) {
    'potplayer' => _potPlayerArgumentsController,
    'custom' => _customArgumentsController,
    _ => _mpvArgumentsController,
  };

  String get _playerLabel => switch (_type) {
    'potplayer' => 'PotPlayer',
    'custom' => '其他播放器',
    _ => 'MPV',
  };

  @override
  void initState() {
    super.initState();
    unawaited(_loadDetectedPlayers());
  }

  @override
  void dispose() {
    _mpvPathController.dispose();
    _mpvArgumentsController.dispose();
    _potPlayerPathController.dispose();
    _potPlayerArgumentsController.dispose();
    _customPathController.dispose();
    _customArgumentsController.dispose();
    super.dispose();
  }

  Future<void> _loadDetectedPlayers({bool refresh = false}) async {
    final detected = await ExternalPlayer.detectInstalledPlayers(
      refresh: refresh,
    );
    if (mounted) setState(() => _detectedPlayers = detected);
  }

  Future<void> _pickProgram() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: Platform.isWindows
            ? const ['exe']
            : Platform.isMacOS
            ? const ['app', 'command']
            : const ['AppImage', 'sh'],
      );
      final selected = result.firstOrNull?.path;
      if (selected == null) return;
      _pathController.text = selected;
    } catch (error) {
      SmartDialog.showToast('选择播放器失败：$error');
    }
  }

  Future<void> _autoDetect() async {
    await _loadDetectedPlayers(refresh: true);
    final detected = _detectedPlayers[_type];
    if (detected == null || detected.isEmpty) {
      SmartDialog.showToast('没有识别到$_playerLabel');
      return;
    }
    _pathController.text = detected;
    SmartDialog.showToast('已识别$_playerLabel');
  }

  Future<void> _save() async {
    await GStorage.setting.put(SettingBoxKey.externalPlayerType, _type);
    await GStorage.setting.put(
      SettingBoxKey.externalPlayerMpvPath,
      _mpvPathController.text.trim(),
    );
    await GStorage.setting.put(
      SettingBoxKey.externalPlayerMpvArguments,
      _mpvArgumentsController.text.trim(),
    );
    await GStorage.setting.put(
      SettingBoxKey.externalPlayerPotPlayerPath,
      _potPlayerPathController.text.trim(),
    );
    await GStorage.setting.put(
      SettingBoxKey.externalPlayerPotPlayerArguments,
      _potPlayerArgumentsController.text.trim(),
    );
    await GStorage.setting.put(
      SettingBoxKey.externalPlayerPath,
      _customPathController.text.trim(),
    );
    await GStorage.setting.put(
      SettingBoxKey.externalPlayerArguments,
      _customArgumentsController.text.trim(),
    );
    if (mounted) SmartDialog.showToast('外部播放器设置已保存');
  }

  @override
  Widget build(BuildContext context) {
    final detected = _detectedPlayers[_type] ?? '';
    return SimpleScaffold(
      appBar: AppBar(
        title: const Text('外部播放器'),
        actions: [
          TextButton(onPressed: _save, child: const Text('保存')),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            value: _type,
            decoration: const InputDecoration(
              labelText: '播放时使用',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'mpv', child: Text('MPV')),
              DropdownMenuItem(value: 'potplayer', child: Text('PotPlayer')),
              DropdownMenuItem(value: 'custom', child: Text('其他播放器')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _type = value);
            },
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_playerLabel 配置',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _pathController,
                    decoration: InputDecoration(
                      labelText: '程序路径',
                      hintText: detected.isNotEmpty
                          ? detected
                          : Platform.isWindows
                          ? r'C:\Program Files\...\player.exe'
                          : '可留空并尝试自动识别',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        tooltip: '浏览',
                        onPressed: _pickProgram,
                        icon: const Icon(Icons.folder_open),
                      ),
                    ),
                  ),
                  if (_type != 'custom') ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _autoDetect,
                        icon: const Icon(Icons.manage_search_outlined),
                        label: const Text('自动识别'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  TextField(
                    controller: _argumentsController,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: '通用启动参数',
                      hintText: '留空使用默认参数模板',
                      helperText: '占位符：{video} 视频、{audio} 音轨、{subtitle} 字幕、{title} 标题、{referer}、{userAgent}。参数按空格分隔，含空格的参数请加引号。',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'MPV 和 PotPlayer 分别保存程序路径与启动参数。路径留空时会从 PATH、常见安装目录和 Windows 注册表识别。',
          ),
        ],
      ),
    );
  }
}
