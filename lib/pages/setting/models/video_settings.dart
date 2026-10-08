import 'dart:io';

import 'package:PiliPlus/models/common/video/audio_quality.dart';
import 'package:PiliPlus/models/common/video/cdn_type.dart';
import 'package:PiliPlus/models/common/video/live_quality.dart';
import 'package:PiliPlus/models/common/video/video_decode_type.dart';
import 'package:PiliPlus/models/common/video/video_quality.dart';
import 'package:PiliPlus/pages/setting/models/model.dart';
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

const _resolverModeDescriptions = <String>[
  '中国大陆普通 HTTP 搜索',
  '香港普通 HTTP 搜索',
  '澳门普通 HTTP 搜索',
  '台湾普通 HTTP 搜索',
  'Intl APP gRPC 搜索；东南亚设置会规范为 INTL',
  'Intl APP gRPC 搜索；东南亚默认值',
  'Intl APP gRPC 搜索',
  '按解析服务器要求填写自定义值',
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
  NormalModel(
    title: 'CDN 设置',
    leading: const Icon(MdiIcons.cloudPlusOutline),
    getSubtitle: () =>
        '当前使用：${VideoUtils.cdnService.desc}，部分 CDN 可能失效，如无法播放请尝试切换',
    onTap: _showCDNDialog,
  ),
  NormalModel(
    title: 'ASS 字幕字体',
    subtitle: '导入字幕字体，libass 同时搜索系统字体',
    leading: const Icon(Icons.font_download_outlined),
    onTap: (context, setState) => Get.toNamed('/subtitleFontSetting'),
  ),
  const SwitchModel(
    title: '自定义番剧解析服务器',
    subtitle: '开启后使用自定义解析服务器搜索观看特定区域的番剧',
    leading: Icon(Icons.travel_explore_outlined),
    setKey: SettingBoxKey.enableBangumiResolver,
  ),
  NormalModel(
    title: '默认解析地区',
    leading: const Icon(Icons.public_outlined),
    getSubtitle: () => BangumiRegion.defaultRegion?.label ?? '未指定，按列表顺序尝试',
    onTap: (context, setState) =>
        _showBangumiDefaultRegion(context).then((_) => setState()),
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

Future<void> _showBangumiDefaultRegion(BuildContext context) async {
  final selected = await showDialog<String>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('默认解析地区'),
      children: [
        for (final value in [
          '',
          ...BangumiRegion.values.map((region) => region.mode),
        ])
          RadioListTile<String>(
            value: value,
            groupValue: BangumiRegion.defaultRegion?.mode ?? '',
            title: Text(
              value.isEmpty
                  ? '未指定，按列表顺序尝试'
                  : BangumiRegion.byMode(value)!.label,
            ),
            onChanged: (value) => Get.back(result: value),
          ),
      ],
    ),
  );
  if (selected == null) return;
  await BangumiRegion.setDefaultRegion(BangumiRegion.byMode(selected));
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
  final currentOption = _resolverModeOption(currentMode);
  final result = await showDialog<_ResolverModeOption>(
    context: context,
    builder: (context) => SelectDialog<_ResolverModeOption>(
      value: currentOption,
      title: '${region.label} resolver_mode（不清楚时保持默认）',
      values: _resolverModeChoices,
      subtitleBuilder: (context, index) => Text(
        _resolverModeDescriptions[index],
      ),
    ),
  );
  if (result == null) return;

  if (result == _ResolverModeOption.custom) {
    final initialValue = currentOption == _ResolverModeOption.custom
        ? currentMode
        : '';
    final customMode = await _editCustomResolverMode(
      context,
      region,
      initialValue,
    );
    if (customMode == null) return;
    await GStorage.setting.put(region.resolverModeKey, customMode);
    return;
  }

  await GStorage.setting.put(
    region.resolverModeKey,
    _resolverModeValue(result),
  );
}

Future<String?> _editCustomResolverMode(
  BuildContext context,
  BangumiRegion region,
  String initialValue,
) async {
  var value = initialValue;
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('${region.label}自定义 resolver_mode'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '自定义值会随番剧搜索发送给解析服务器。东南亚的 TH 会按兼容规则规范为 INTL。不清楚时请使用默认值 ${region.mode}。',
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: initialValue,
            autofocus: true,
            maxLength: 64,
            keyboardType: TextInputType.text,
            onChanged: (text) => value = text.trim(),
            decoration: const InputDecoration(
              hintText: '输入解析服务器要求的值',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () {
            final result = value.trim();
            if (result.isEmpty) {
              SmartDialog.showToast('请输入自定义 resolver_mode');
              return;
            }
            Navigator.of(dialogContext).pop(result);
          },
          child: const Text('保存'),
        ),
      ],
    ),
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
      title: '首选解码格式',
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
      title: '蜂窝网络首选解码格式',
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
      title: '音频输出设备',
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
      title: '硬解模式',
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
