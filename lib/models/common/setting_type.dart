import 'package:PiliPlus/pages/setting/models/developer_settings.dart';
import 'package:PiliPlus/pages/setting/models/extra_settings.dart';
import 'package:PiliPlus/pages/setting/models/model.dart';
import 'package:PiliPlus/pages/setting/models/play_settings.dart';
import 'package:PiliPlus/pages/setting/models/privacy_settings.dart';
import 'package:PiliPlus/pages/setting/models/recommend_settings.dart';
import 'package:PiliPlus/pages/setting/models/style_settings.dart';
import 'package:PiliPlus/pages/setting/models/video_settings.dart';

enum SettingType {
  playback('播放控制'),
  quality('音视频与字幕'),
  bangumi('番剧解析'),
  browse('首页与搜索'),
  content('视频与内容'),
  community('评论与动态'),
  appearance('界面与导航'),
  privacy('账号与隐私'),
  storage('网络与存储'),
  general('通用与设备'),
  developer('开发者'),
  webdav('WebDAV'),
  about('关于');

  final String title;
  const SettingType(this.title);

  List<SettingsModel> get settings => switch (this) {
    .playback =>
      playSettings
          .where(
            (item) =>
                item.effectiveTitle != '字幕设置' &&
                item.effectiveTitle != '弹幕开关' &&
                item.effectiveTitle != '启用点击弹幕',
          )
          .toList(),
    .quality => [
      ...qualityAudioSettings,
      ...qualityEnhancementSettings,
      const SettingSectionModel('字幕'),
      ...playSettings.where(
        (item) => item.effectiveTitle == '字幕设置',
      ),
      ...subtitleSettings,
      const SettingSectionModel('弹幕'),
      ...playSettings.where(
        (item) => const {'弹幕开关', '启用点击弹幕'}.contains(item.effectiveTitle),
      ),
      ...danmakuSettings,
    ],
    .bangumi => bangumiResolverSettings,
    .browse => [...recommendSettings, ...searchSettings],
    .content => contentSettings,
    .community => communitySettings,
    .appearance => styleSettings,
    .privacy => privacySettings,
    .storage => networkSettings,
    .general => extraSettings,
    .developer => developerSettings,
    .webdav || .about => const [],
  };
}
