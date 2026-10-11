import 'dart:io';

import 'package:PiliPlus/models/common/video/audio_quality.dart';
import 'package:PiliPlus/models/common/video/cdn_type.dart';
import 'package:PiliPlus/models/common/video/live_quality.dart';
import 'package:PiliPlus/models/common/video/video_decode_type.dart';
import 'package:PiliPlus/models/common/video/video_quality.dart';
import 'package:PiliPlus/pages/setting/models/model.dart';
import 'package:PiliPlus/pages/setting/pages/external_player_setting.dart';
import 'package:PiliPlus/pages/setting/widgets/ordered_multi_select_dialog.dart';
import 'package:PiliPlus/pages/setting/widgets/select_dialog.dart';
import 'package:PiliPlus/plugin/pl_player/models/audio_output_type.dart';
import 'package:PiliPlus/plugin/pl_player/models/hwdec_type.dart';
import 'package:PiliPlus/utils/filtering_text.dart';
import 'package:PiliPlus/utils/bangumi_resolver.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/video_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart';

enum _ResolverModeOption { cn, hk, mo, tw, th, intl, sea, custom }

const _resolverModeChoices = <(_ResolverModeOption, String)>[
  (_ResolverModeOption.cn, 'CN'),
  (_ResolverModeOption.hk, 'HK'),
  (_ResolverModeOption.mo, 'MO'),
  (_ResolverModeOption.tw, 'TW'),
  (_ResolverModeOption.th, 'TH（兼容值）'),
  (_ResolverModeOption.intl, 'INTL'),
  (_ResolverModeOption.sea, 'SEA'),
  (_ResolverModeOption.custom, '自定义'),
];

_ResolverModeOption _resolverModeOption(String value) =>
    switch (value.toUpperCase()) {
      'CN' => _ResolverModeOption.cn,
      'HK' => _ResolverModeOption.hk,
      'MO' => _ResolverModeOption.mo,
      'TW' => _ResolverModeOption.tw,
      'TH' => _ResolverModeOption.th,
      'INTL' => _ResolverModeOption.intl,
      'SEA' => _ResolverModeOption.sea,
      _ => _ResolverModeOption.custom,
    };

String _resolverModeValue(_ResolverModeOption option) => switch (option) {
  _ResolverModeOption.cn => 'CN',
  _ResolverModeOption.hk => 'HK',
  _ResolverModeOption.mo => 'MO',
  _ResolverModeOption.tw => 'TW',
  _ResolverModeOption.th => 'TH',
  _ResolverModeOption.intl => 'INTL',
  _ResolverModeOption.sea => 'SEA',
  _ResolverModeOption.custom => '',
};

String _resolverModeSubtitle(BangumiRegion region) {
  final mode = region.resolverMode;
  return _resolverModeOption(mode) == _ResolverModeOption.custom
      ? '$mode（自定义）'
      : '$mode（默认：${region.mode}）';
}

List<SettingsModel> get videoSettings => [
  const SettingSectionModel('MPV 播放器（libmpv）'),
  const NormalModel(
    title: '播放器内核',
    subtitle: 'MPV（libmpv）',
    leading: Icon(Icons.movie_filter_outlined),
  ),
  const SwitchModel(
    title: '视频插帧',
    subtitle: '使用 MPV 插帧平滑运动画面；下次播放生效',
    leading: Icon(Icons.motion_photos_auto_outlined),
    setKey: SettingBoxKey.mpvInterpolation,
    defaultVal: false,
  ),
  NormalModel(
    title: 'MPV 视频输出驱动',
    leading: const Icon(Icons.monitor_outlined),
    getSubtitle: () => '当前：${Pref.mpvVideoOutput}',
    onTap: _showMpvVideoOutput,
  ),
  NormalModel(
    title: 'MPV 音轨语言顺序',
    subtitle: '控制 MPV 内置音轨语言选择顺序',
    leading: const Icon(Icons.audiotrack_outlined),
    getSubtitle: () => Pref.mpvAudioLanguage,
    onTap: (context, setState) => _editMpvLanguage(
      context,
      'MPV 音轨语言顺序',
      SettingBoxKey.mpvAudioLanguage,
      Pref.mpvAudioLanguage,
    ).then((_) => setState()),
  ),
  NormalModel(
    title: 'MPV 字幕语言顺序',
    subtitle: '控制 MPV 内置字幕轨道语言选择顺序',
    leading: const Icon(Icons.subtitles_outlined),
    getSubtitle: () => Pref.mpvSubtitleLanguage,
    onTap: (context, setState) => _editMpvLanguage(
      context,
      'MPV 字幕语言顺序',
      SettingBoxKey.mpvSubtitleLanguage,
      Pref.mpvSubtitleLanguage,
    ).then((_) => setState()),
  ),
  const SwitchModel(
    title: '默认全屏播放',
    subtitle: '自动播放时直接进入全屏',
    leading: Icon(Icons.fullscreen_outlined),
    setKey: SettingBoxKey.mpvStartFullscreen,
    defaultVal: false,
  ),
  const SwitchModel(
    title: 'MPV 缓存',
    subtitle: '关闭后停用 MPV 网络缓存',
    leading: Icon(Icons.cached_outlined),
    setKey: SettingBoxKey.mpvCacheEnabled,
    defaultVal: true,
  ),
  const SwitchModel(
    title: '自动加载同目录字幕',
    subtitle: '播放本地视频时查找同名字幕文件',
    leading: Icon(Icons.subtitles_outlined),
    setKey: SettingBoxKey.mpvSubtitleAutoLoad,
    defaultVal: true,
  ),
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS)
    NormalModel(
      title: '外部播放器',
      subtitle: '配置 MPV、PotPlayer 或其他播放器',
      leading: const Icon(Icons.open_in_new),
      onTap: (context, setState) =>
          Get.to(() => const ExternalPlayerSettingsPage()),
    ),
  const SwitchModel(
    title: '去色带',
    subtitle: '减少渐变画面中的色带；下次播放生效',
    leading: Icon(Icons.gradient_outlined),
    setKey: SettingBoxKey.mpvDeband,
    defaultVal: false,
  ),
  const SettingSectionModel('播放能力'),
  const SwitchModel(
    title: '开启硬解',
    subtitle: '以较低功耗播放视频，若异常卡死请关闭',
    leading: Icon(Icons.flash_on_outlined),
    setKey: SettingBoxKey.enableHA,
    defaultVal: true,
  ),
  const SwitchModel(
    title: '免登录1080P',
    subtitle: '免登录查看1080P视频',
    leading: Icon(Icons.hd_outlined),
    setKey: SettingBoxKey.p1080,
    defaultVal: true,
  ),
  NormalModel(
    title: 'B站定向流量支持',
    subtitle: '若套餐含B站定向流量，则会自动使用。可查阅运营商的流量记录确认。',
    leading: const Icon(Icons.perm_data_setting_outlined),
    getTrailing: (theme) => IgnorePointer(
      child: Transform.scale(
        scale: 0.8,
        alignment: Alignment.centerRight,
        child: Switch(
          value: true,
          onChanged: (_) {},
          thumbIcon: WidgetStateProperty.all(
            const Icon(Icons.lock_outline_rounded),
          ),
        ),
      ),
    ),
  ),
  const SettingSectionModel('番剧地区解析'),
  const SwitchModel(
    title: '自定义番剧解析服务器',
    subtitle: '开启后使用自定义解析服务器搜索观看特定区域的番剧',
    leading: Icon(Icons.travel_explore_outlined),
    setKey: SettingBoxKey.enableBangumiResolver,
  ),
  for (final region in BangumiRegion.values) ...[
    NormalModel(
      title: '${region.label}番剧解析服务器',
      leading: const Icon(Icons.dns_outlined),
      getSubtitle: () => region.resolver.isEmpty ? '未设置' : region.resolver,
      onTap: (context, setState) => _editResolverValue(
        context,
        region.resolverKey,
        '${region.label}番剧解析服务器 URL',
      ).then((_) => setState()),
    ),
    NormalModel(
      title: '${region.label} resolver_mode',
      getSubtitle: () => _resolverModeSubtitle(region),
      leading: const Icon(Icons.tune_outlined),
      onTap: (context, setState) =>
          _editResolverMode(context, region).then((_) => setState()),
    ),
    NormalModel(
      title: '${region.label}番剧 CDN',
      leading: const Icon(MdiIcons.cloudOutline),
      getSubtitle: () => switch ((region.cdnService, region.legacyCdnHost)) {
        (final service?, _) => service.desc,
        (null, final host?) => '旧自定义 CDN：$host',
        _ => '跟随常规视频 CDN 设置',
      },
      onTap: (context, setState) =>
          _showBangumiCdnDialog(context, region).then((_) => setState()),
    ),
  ],
  const SettingSectionModel('CDN 与线路'),
  NormalModel(
    title: 'CDN 设置',
    leading: const Icon(MdiIcons.cloudPlusOutline),
    getSubtitle: () =>
        '当前使用：${VideoUtils.cdnService.desc}，部分 CDN 可能失效，如无法播放请尝试切换',
    onTap: _showCDNDialog,
  ),
  NormalModel(
    title: '直播 CDN 设置',
    leading: const Icon(MdiIcons.cloudPlusOutline),
    getSubtitle: () => '当前使用：${Pref.liveCdnUrl ?? "默认"}',
    onTap: _showLiveCDNDialog,
  ),
  const SwitchModel(
    title: 'CDN 测速',
    leading: Icon(Icons.speed),
    subtitle: '测速通过模拟加载视频实现，注意流量消耗，结果仅供参考',
    setKey: SettingBoxKey.cdnSpeedTest,
    defaultVal: true,
  ),
  SwitchModel(
    title: '音频不跟随 CDN 设置',
    subtitle: '直接采用备用 URL，可解决部分视频无声',
    leading: const Icon(MdiIcons.musicNotePlus),
    setKey: SettingBoxKey.disableAudioCDN,
    defaultVal: false,
    onChanged: (value) => VideoUtils.disableAudioCDN = value,
  ),
  const SettingSectionModel('画质与音质'),
  NormalModel(
    title: '默认画质',
    leading: const Icon(Icons.video_settings_outlined),
    getSubtitle: () =>
        '当前画质：${VideoQuality.fromCode(Pref.defaultVideoQa).desc}',
    onTap: _showVideoQaDialog,
  ),
  NormalModel(
    title: '蜂窝网络画质',
    leading: const Icon(Icons.video_settings_outlined),
    getSubtitle: () =>
        '当前画质：${VideoQuality.fromCode(Pref.defaultVideoQaCellular).desc}',
    onTap: _showVideoCellularQaDialog,
  ),
  NormalModel(
    title: '默认音质',
    leading: const Icon(Icons.music_video_outlined),
    getSubtitle: () =>
        '当前音质：${AudioQuality.fromCode(Pref.defaultAudioQa).desc}',
    onTap: _showAudioQaDialog,
  ),
  NormalModel(
    title: '蜂窝网络音质',
    leading: const Icon(Icons.music_video_outlined),
    getSubtitle: () =>
        '当前音质：${AudioQuality.fromCode(Pref.defaultAudioQaCellular).desc}',
    onTap: _showAudioCellularQaDialog,
  ),
  NormalModel(
    title: '直播默认画质',
    leading: const Icon(Icons.video_settings_outlined),
    getSubtitle: () => '当前画质：${LiveQuality.fromCode(Pref.liveQuality)?.desc}',
    onTap: _showLiveQaDialog,
  ),
  NormalModel(
    title: '蜂窝网络直播默认画质',
    leading: const Icon(Icons.video_settings_outlined),
    getSubtitle: () =>
        '当前画质：${LiveQuality.fromCode(Pref.liveQualityCellular)?.desc}',
    onTap: _showLiveCellularQaDialog,
  ),
  NormalModel(
    title: '首选解码格式',
    leading: const Icon(Icons.movie_creation_outlined),
    getSubtitle: () =>
        '首选解码格式：${(Pref.preferCodecs.map((i) => i.name).join(","))}，请根据设备支持情况与需求调整',
    onTap: _showCodecsDialog,
  ),
  NormalModel(
    title: '蜂窝网络首选解码格式',
    leading: const Icon(Icons.movie_creation_outlined),
    getSubtitle: () =>
        '首选解码格式：${(Pref.preferCodecsCellular.map((i) => i.name).join(","))}，请根据设备支持情况与需求调整',
    onTap: _showCellularCodecsDialog,
  ),
  const SettingSectionModel('解码与缓冲'),
  if (kDebugMode || Platform.isAndroid)
    NormalModel(
      title: '音频输出设备',
      leading: const Icon(Icons.speaker_outlined),
      getSubtitle: () => '当前：${Pref.audioOutput}',
      onTap: _showAudioOutputDialog,
    ),
  NormalModel(
    title: '缓冲大小',
    leading: const Icon(Icons.storage_outlined),
    getSubtitle: () =>
        '当前：${Pref.bufferSize}MB。同时为前向和后向缓冲区大小。对于直播流，无后向缓冲大小，全部转给前向（此选项即mpv的--demuxer-max-bytes，--demuxer-max-back-bytes）',
    onTap: _showBufferSizeDialog,
  ),
  NormalModel(
    title: '缓冲时长',
    leading: const Icon(Icons.av_timer),
    getSubtitle: () =>
        '当前：${Pref.bufferSec}s。实际缓冲为二者最小值。对于直播流，该选项无效（此选项即mpv的--cache-secs）',
    onTap: _showBufferSecDialog,
  ),
  NormalModel(
    title: '自动同步',
    leading: const Icon(Icons.sync_rounded),
    getSubtitle: () => '当前：${Pref.autosync}（此项即mpv的--autosync）',
    onTap: _showAutoSyncDialog,
  ),
  NormalModel(
    title: '视频同步',
    leading: const Icon(Icons.view_timeline_outlined),
    getSubtitle: () => '当前：${Pref.videoSync}（此项即mpv的--video-sync）',
    onTap: _showVideoSyncDialog,
  ),
  NormalModel(
    title: '硬解模式',
    leading: const Icon(Icons.memory_outlined),
    getSubtitle: () => '当前：${Pref.hardwareDecoding}（此项即mpv的--hwdec）',
    onTap: _showHwDecDialog,
  ),
];

List<SettingsModel> get bangumiResolverSettings {
  final settings = videoSettings;
  final start = settings.indexWhere(
    (item) => item is SettingSectionModel && item.title == '番剧地区解析',
  );
  final end = settings.indexWhere(
    (item) => item is SettingSectionModel && item.title == 'CDN 与线路',
  );
  if (start < 0) return const [];
  return settings.sublist(start, end < 0 ? settings.length : end);
}

List<SettingsModel> get qualityAudioSettings {
  final regionalTitles = bangumiResolverSettings
      .map((item) => item.effectiveTitle)
      .toSet();
  return videoSettings
      .where((item) => !regionalTitles.contains(item.effectiveTitle))
      .toList();
}

Future<void> _showMpvVideoOutput(
  BuildContext context,
  VoidCallback setState,
) async {
  const options = <(String, String)>[
    ('auto', 'auto（自动）'),
    ('gpu', 'gpu（兼容模式）'),
    ('gpu-next', 'gpu-next（新渲染器）'),
  ];
  final result = await showDialog<String>(
    context: context,
    builder: (context) => SelectDialog<String>(
      title: 'MPV 视频输出驱动',
      value: Pref.mpvVideoOutput,
      values: options,
    ),
  );
  if (result == null) return;
  await GStorage.setting.put(SettingBoxKey.mpvVideoOutput, result);
  setState();
}

Future<void> _editMpvLanguage(
  BuildContext context,
  String title,
  String key,
  String current,
) async {
  var value = current;
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextFormField(
        autofocus: true,
        initialValue: current,
        onChanged: (text) => value = text.trim(),
        decoration: const InputDecoration(
          hintText: '逗号分隔，例如 zh,zh-CN,ja,en',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(onPressed: Get.back, child: const Text('取消')),
        TextButton(
          onPressed: () => Get.back(result: value),
          child: const Text('保存'),
        ),
      ],
    ),
  );
  if (result != null) await GStorage.setting.put(key, result);
}

Future<void> _editResolverValue(
  BuildContext context,
  String key,
  String title,
) async {
  var value = GStorage.setting.get(key, defaultValue: '') as String;
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextFormField(
        initialValue: value,
        autofocus: true,
        keyboardType: TextInputType.url,
        onChanged: (text) => value = text.trim(),
        decoration: InputDecoration(
          hintText: key.startsWith('bangumiResolver')
              ? '域名或 HTTP(S) 地址；公网默认 HTTPS，私网或非 443 端口默认 HTTP'
              : '留空则不使用',
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(onPressed: Get.back, child: const Text('取消')),
        TextButton(
          onPressed: () => Get.back(result: value),
          child: const Text('保存'),
        ),
      ],
    ),
  );
  if (result == null) return;
  if (result.isNotEmpty &&
      (key.startsWith('bangumiResolver') || key.startsWith('bangumiCdn'))) {
    final isCdn = key.startsWith('bangumiCdn');
    if (isCdn) {
      final uri = Uri.tryParse(result);
      if (uri == null || uri.host.isEmpty) {
        SmartDialog.showToast('请输入有效 CDN host');
        return;
      }
    } else {
      try {
        value = BangumiRegion.normalizeResolverAddress(result);
      } on FormatException {
        SmartDialog.showToast('请输入域名或 HTTP(S) 地址，例如 intl.pre-s.com');
        return;
      }
    }
  }
  await GStorage.setting.put(key, value);
}

Future<void> _editResolverMode(
  BuildContext context,
  BangumiRegion region,
) async {
  final currentMode = region.resolverMode;
  var selectedOption = _resolverModeOption(currentMode);
  var customMode = selectedOption == _ResolverModeOption.custom
      ? currentMode
      : '';
  final result = await showDialog<(_ResolverModeOption, String?)>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text('${region.label} resolver_mode（不清楚时保持默认）'),
        content: SizedBox(
          width: 400,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 480),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioGroup<_ResolverModeOption>(
                    groupValue: selectedOption,
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => selectedOption = value);
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final (option, label) in _resolverModeChoices)
                          RadioListTile<_ResolverModeOption>(
                            value: option,
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(label),
                          ),
                      ],
                    ),
                  ),
                  if (selectedOption == _ResolverModeOption.custom) ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      autofocus: true,
                      initialValue: customMode,
                      maxLength: 64,
                      onChanged: (value) => customMode = value.trim(),
                      decoration: const InputDecoration(
                        labelText: '自定义值',
                        hintText: '输入解析服务器要求的值',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              if (selectedOption == _ResolverModeOption.custom &&
                  customMode.trim().isEmpty) {
                SmartDialog.showToast('请输入自定义 resolver_mode');
                return;
              }
              Navigator.of(context).pop((selectedOption, customMode.trim()));
            },
            child: const Text('保存'),
          ),
        ],
      ),
    ),
  );
  if (result == null) return;

  final (option, value) = result;
  if (option == _ResolverModeOption.custom) {
    await GStorage.setting.put(region.resolverModeKey, value);
    return;
  }

  await GStorage.setting.put(
    region.resolverModeKey,
    _resolverModeValue(option),
  );
}

Future<void> _showCDNDialog(BuildContext context, VoidCallback setState) async {
  final res = await showDialog<CDNService>(
    context: context,
    builder: (context) => const CdnSelectDialog(),
  );
  if (res != null) {
    VideoUtils.cdnService = res;
    await GStorage.setting.put(SettingBoxKey.CDNService, res.name);
    setState();
  }
}

Future<void> _showBangumiCdnDialog(
  BuildContext context,
  BangumiRegion region,
) async {
  final selectedValue =
      region.cdnService?.name ??
      (region.legacyCdnHost == null ? 'follow' : 'legacy');
  final result = await showDialog<String>(
    context: context,
    builder: (context) => BangumiCdnSelectDialog(
      title: '${region.label}番剧 CDN',
      selectedValue: selectedValue,
      legacyLabel: region.legacyCdnHost,
    ),
  );
  if (result == null || result == 'legacy') return;
  await GStorage.setting.put(
    region.cdnKey,
    result == 'follow' ? '' : result,
  );
}

Future<void> _showLiveCDNDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  String host = Pref.liveCdnUrl ?? '';
  String? res = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('输入CDN host'),
      content: TextFormField(
        initialValue: host,
        autofocus: true,
        onChanged: (value) => host = value,
      ),
      actions: [
        TextButton(
          onPressed: Get.back,
          child: Text(
            '取消',
            style: TextStyle(color: ColorScheme.of(context).outline),
          ),
        ),
        TextButton(
          onPressed: () => Get.back(result: host),
          child: const Text('确定'),
        ),
      ],
    ),
  );
  if (res != null) {
    if (res.isEmpty) {
      res = null;
      await GStorage.setting.delete(SettingBoxKey.liveCdnUrl);
    } else {
      if (!res.startsWith('http')) {
        res = 'https://$res';
      }
      await GStorage.setting.put(SettingBoxKey.liveCdnUrl, res);
    }
    VideoUtils.liveCdnUrl = res;
    setState();
  }
}

Future<void> _showVideoQaDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<int>(
    context: context,
    builder: (context) => SelectDialog<int>(
      title: '默认画质',
      value: Pref.defaultVideoQa,
      values: VideoQuality.values.map((e) => (e.code, e.desc)).toList(),
    ),
  );
  if (res != null) {
    await GStorage.setting.put(SettingBoxKey.defaultVideoQa, res);
    setState();
  }
}

Future<void> _showVideoCellularQaDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<int>(
    context: context,
    builder: (context) => SelectDialog<int>(
      title: '蜂窝网络画质',
      value: Pref.defaultVideoQaCellular,
      values: VideoQuality.values.map((e) => (e.code, e.desc)).toList(),
    ),
  );
  if (res != null) {
    await GStorage.setting.put(SettingBoxKey.defaultVideoQaCellular, res);
    setState();
  }
}

Future<void> _showAudioQaDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<int>(
    context: context,
    builder: (context) => SelectDialog<int>(
      title: '默认音质',
      value: Pref.defaultAudioQa,
      values: AudioQuality.values.map((e) => (e.code, e.desc)).toList(),
    ),
  );
  if (res != null) {
    await GStorage.setting.put(SettingBoxKey.defaultAudioQa, res);
    setState();
  }
}

Future<void> _showAudioCellularQaDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<int>(
    context: context,
    builder: (context) => SelectDialog<int>(
      title: '蜂窝网络音质',
      value: Pref.defaultAudioQaCellular,
      values: AudioQuality.values.map((e) => (e.code, e.desc)).toList(),
    ),
  );
  if (res != null) {
    await GStorage.setting.put(SettingBoxKey.defaultAudioQaCellular, res);
    setState();
  }
}

Future<void> _showLiveQaDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<int>(
    context: context,
    builder: (context) => SelectDialog<int>(
      title: '直播默认画质',
      value: Pref.liveQuality,
      values: LiveQuality.values.map((e) => (e.code, e.desc)).toList(),
    ),
  );
  if (res != null) {
    await GStorage.setting.put(SettingBoxKey.liveQuality, res);
    setState();
  }
}

Future<void> _showLiveCellularQaDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<int>(
    context: context,
    builder: (context) => SelectDialog<int>(
      title: '蜂窝网络直播默认画质',
      value: Pref.liveQualityCellular,
      values: LiveQuality.values.map((e) => (e.code, e.desc)).toList(),
    ),
  );
  if (res != null) {
    await GStorage.setting.put(SettingBoxKey.liveQualityCellular, res);
    setState();
  }
}

Future<void> _showCodecsDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<List<VideoDecodeFormatType>>(
    context: context,
    builder: (context) => OrderedMultiSelectDialog<VideoDecodeFormatType>(
      title: const Text('首选解码格式'),
      initValues: Pref.preferCodecs,
      values: {for (final e in VideoDecodeFormatType.values) e: e.name},
    ),
  );
  if (res != null && res.isNotEmpty) {
    await GStorage.setting.put(
      SettingBoxKey.preferCodecs,
      res.map((i) => i.name).toList(),
    );
    setState();
  }
}

Future<void> _showCellularCodecsDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<List<VideoDecodeFormatType>>(
    context: context,
    builder: (context) => OrderedMultiSelectDialog<VideoDecodeFormatType>(
      title: const Text('蜂窝网络首选解码格式'),
      initValues: Pref.preferCodecsCellular,
      values: {for (final e in VideoDecodeFormatType.values) e: e.name},
    ),
  );
  if (res != null && res.isNotEmpty) {
    await GStorage.setting.put(
      SettingBoxKey.preferCodecsCellular,
      res.map((i) => i.name).toList(),
    );
    setState();
  }
}

Future<void> _showAudioOutputDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<List<String>>(
    context: context,
    builder: (context) => OrderedMultiSelectDialog<String>(
      title: const Text('音频输出设备'),
      initValues: Pref.audioOutput.split(','),
      values: {for (final e in AudioOutput.values) e.name: e.label},
    ),
  );
  if (res != null && res.isNotEmpty) {
    await GStorage.setting.put(SettingBoxKey.audioOutput, res.join(','));
    setState();
  }
}

Future<void> _showVideoSyncDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<String>(
    context: context,
    builder: (context) => SelectDialog<String>(
      title: '视频同步',
      value: Pref.videoSync,
      values: const [
        'audio',
        'display-resample',
        'display-resample-vdrop',
        'display-resample-desync',
        'display-tempo',
        'display-vdrop',
        'display-adrop',
        'display-desync',
        'desync',
      ].map((e) => (e, e)).toList(),
    ),
  );
  if (res != null) {
    await GStorage.setting.put(SettingBoxKey.videoSync, res);
    setState();
  }
}

Future<void> _showHwDecDialog(
  BuildContext context,
  VoidCallback setState,
) async {
  final res = await showDialog<List<String>>(
    context: context,
    builder: (context) => OrderedMultiSelectDialog<String>(
      title: const Text('硬解模式'),
      initValues: Pref.hardwareDecoding.split(','),
      values: {
        for (final e in HwDecType.values) e.hwdec: '${e.hwdec}\n${e.desc}',
      },
    ),
  );
  if (res != null && res.isNotEmpty) {
    await GStorage.setting.put(SettingBoxKey.hardwareDecoding, res.join(','));
    setState();
  }
}

void _showAutoSyncDialog(BuildContext context, VoidCallback setState) {
  String autosync = Pref.autosync.toString();
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('自动同步'),
      content: TextFormField(
        autofocus: true,
        initialValue: autosync,
        keyboardType: TextInputType.number,
        onChanged: (value) => autosync = value,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      ),
      actions: [
        TextButton(
          onPressed: Get.back,
          child: Text(
            '取消',
            style: TextStyle(color: ColorScheme.of(context).outline),
          ),
        ),
        TextButton(
          onPressed: () async {
            try {
              // validate
              int.parse(autosync);
              Get.back();
              await GStorage.setting.put(SettingBoxKey.autosync, autosync);
              setState();
            } catch (e) {
              SmartDialog.showToast(e.toString());
            }
          },
          child: const Text('确定'),
        ),
      ],
    ),
  );
}

void _showDecimalDialog(
  BuildContext context,
  VoidCallback setState, {
  required String key,
  required double defVal,
  required String title,
  required String? suffix,
}) {
  String value = (GStorage.setting.get(key) ?? defVal).toString();
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextFormField(
        autofocus: true,
        initialValue: value,
        keyboardType: const .numberWithOptions(decimal: true),
        onChanged: (val) => value = val,
        inputFormatters: FilteringText.decimal,
        decoration: suffix == null ? null : InputDecoration(suffixText: suffix),
      ),
      actions: [
        TextButton(
          onPressed: Get.back,
          child: Text(
            '取消',
            style: TextStyle(color: ColorScheme.of(context).outline),
          ),
        ),
        TextButton(
          onPressed: () async {
            try {
              final val = double.parse(value);
              Get.back();
              await GStorage.setting.put(key, val);
              setState();
            } catch (e) {
              SmartDialog.showToast(e.toString());
            }
          },
          child: const Text('确定'),
        ),
      ],
    ),
  );
}

void _showBufferSizeDialog(BuildContext context, VoidCallback setState) =>
    _showDecimalDialog(
      context,
      setState,
      key: SettingBoxKey.bufferSize,
      defVal: Pref.bufferSize,
      title: '缓冲大小',
      suffix: 'MB',
    );

void _showBufferSecDialog(BuildContext context, VoidCallback setState) =>
    _showDecimalDialog(
      context,
      setState,
      key: SettingBoxKey.bufferSec,
      defVal: Pref.bufferSec,
      title: '缓冲时长',
      suffix: 's',
    );
