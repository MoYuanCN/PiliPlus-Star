import 'dart:io';

import 'package:PiliPlus/build_config.dart';
import 'package:PiliPlus/pages/setting/models/model.dart';
import 'package:PiliPlus/pages/setting/pages/mpv_developer_setting.dart';
import 'package:PiliPlus/pages/setting/widgets/select_dialog.dart';
import 'package:PiliPlus/utils/mpv_config.dart';
import 'package:PiliPlus/utils/path_utils.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/services.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

List<SettingsModel> get developerSettings => [
  const SettingSectionModel('开发者工具'),
  const SwitchModel(
    title: '开发者模式',
    subtitle: '启用 MPV 配置编辑、播放器日志和诊断工具',
    leading: Icon(Icons.developer_mode_outlined),
    setKey: SettingBoxKey.developerModeEnabled,
    defaultVal: false,
  ),
  NormalModel(
    title: 'MPV 日志级别',
    leading: const Icon(Icons.article_outlined),
    getSubtitle: () => '${Pref.mpvLogLevel} · 开启开发者模式后读取',
    onTap: _selectLogLevel,
  ),
  NormalModel(
    title: 'MPV 高级配置',
    subtitle: '编辑 mpv.conf 与 input.conf；启用开发者模式后读取',
    leading: const Icon(Icons.tune),
    onTap: (context, setState) =>
        Get.to(() => const MpvDeveloperSettingsPage()),
  ),
  NormalModel(
    title: '打开 MPV 配置目录',
    getSubtitle: () => MpvConfig.directoryPath,
    leading: const Icon(Icons.folder_open_outlined),
    onTap: (context, setState) async {
      await MpvConfig.ensureDirectory();
      await PathUtils.openDir(MpvConfig.directoryPath);
    },
  ),
  NormalModel(
    title: '复制诊断信息',
    subtitle: '复制版本、系统和 MPV 设置，不包含账号凭据',
    leading: const Icon(Icons.content_copy_outlined),
    onTap: (context, setState) async {
      final text = [
        'PiliPlus-Star ${BuildConfig.versionName}+${BuildConfig.versionCode}',
        'Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
        'MPV vo: ${Pref.mpvVideoOutput}',
        'MPV log: ${Pref.mpvLogLevel}',
        'MPV cache: ${Pref.mpvCacheEnabled}',
        'Subtitle font: ${Pref.subtitleFontFamily}',
      ].join('\n');
      await Clipboard.setData(ClipboardData(text: text));
      SmartDialog.showToast('诊断信息已复制');
    },
  ),
];

Future<void> _selectLogLevel(
  BuildContext context,
  VoidCallback setState,
) async {
  const values = <(String, String)>[
    ('error', 'error'),
    ('warn', 'warn'),
    ('info', 'info'),
    ('verbose', 'verbose'),
    ('debug', 'debug'),
  ];
  final selected = await showDialog<String>(
    context: context,
    builder: (context) => SelectDialog<String>(
      title: 'MPV 日志级别',
      value: Pref.mpvLogLevel,
      values: values,
    ),
  );
  if (selected == null) return;
  await GStorage.setting.put(SettingBoxKey.mpvLogLevel, selected);
  setState();
}
