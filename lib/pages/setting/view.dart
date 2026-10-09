import 'package:PiliPlus/common/widgets/flutter/list_tile.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/common/widgets/view_safe_area.dart';
import 'package:PiliPlus/http/login.dart';
import 'package:PiliPlus/models/common/setting_type.dart';
import 'package:PiliPlus/pages/about/view.dart';
import 'package:PiliPlus/pages/login/controller.dart';
import 'package:PiliPlus/pages/setting/common_setting.dart';
import 'package:PiliPlus/pages/setting/widgets/multi_select_dialog.dart';
import 'package:PiliPlus/pages/webdav/view.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/accounts/account.dart';
import 'package:PiliPlus/utils/extension/size_ext.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:material_ui/material_ui.dart' hide ListTile;

class _SettingsModel {
  final SettingType type;
  final String? subtitle;
  final Icon icon;

  const _SettingsModel({
    required this.type,
    this.subtitle,
    required this.icon,
  });
}

class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  late SettingType _type = SettingType.playback;
  final RxBool _noAccount = Accounts.account.isEmpty.obs;
  late bool _isPortrait;
  late ThemeData theme;

  static const List<_SettingsModel> _items = [
    _SettingsModel(
      type: SettingType.playback,
      subtitle: '倍速、手势、全屏与播放器控件',
      icon: Icon(Icons.play_circle_outline),
    ),
    _SettingsModel(
      type: SettingType.quality,
      subtitle: '画质、音轨、字幕、弹幕、解码与缓存',
      icon: Icon(Icons.high_quality_outlined),
    ),
    _SettingsModel(
      type: SettingType.bangumi,
      subtitle: '各地区番剧解析服务器与 CDN',
      icon: Icon(Icons.public_outlined),
    ),
    _SettingsModel(
      type: SettingType.browse,
      subtitle: '首页推荐、搜索和快捷收藏',
      icon: Icon(Icons.explore_outlined),
    ),
    _SettingsModel(
      type: SettingType.content,
      subtitle: '视频详情、图片预览与播放扩展',
      icon: Icon(Icons.video_library_outlined),
    ),
    _SettingsModel(
      type: SettingType.community,
      subtitle: '评论、动态、消息与 UP 主主页',
      icon: Icon(Icons.forum_outlined),
    ),
    _SettingsModel(
      type: SettingType.appearance,
      subtitle: '界面布局、导航位置、字体与主题',
      icon: Icon(Icons.style_outlined),
    ),
    _SettingsModel(
      type: SettingType.privacy,
      subtitle: '账号管理与内容屏蔽',
      icon: Icon(Icons.privacy_tip_outlined),
    ),
    _SettingsModel(
      type: SettingType.storage,
      subtitle: '连接、缓存路径、存储与更新',
      icon: Icon(Icons.settings_ethernet_outlined),
    ),
    _SettingsModel(
      type: SettingType.general,
      subtitle: '触控、设备适配与通用行为',
      icon: Icon(Icons.tune_outlined),
    ),
    _SettingsModel(
      type: SettingType.developer,
      subtitle: 'MPV 配置、日志与诊断工具',
      icon: Icon(Icons.developer_mode_outlined),
    ),
    _SettingsModel(
      type: SettingType.webdav,
      icon: Icon(MdiIcons.databaseCogOutline),
    ),
    _SettingsModel(
      type: SettingType.about,
      icon: Icon(Icons.info_outline),
    ),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    theme = Theme.of(context);
    _isPortrait = MediaQuery.sizeOf(context).isPortrait;
  }

  @override
  Widget build(BuildContext context) {
    return SimpleScaffold(
      appBar: AppBar(
        title: _isPortrait ? const Text('设置') : Text(_type.title),
      ),
      body: ViewSafeArea(
        child: _isPortrait
            ? _buildList(theme)
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: _buildList(theme),
                  ),
                  VerticalDivider(
                    width: 1,
                    color: theme.colorScheme.outline.withValues(alpha: 0.1),
                  ),
                  Expanded(
                    flex: 6,
                    child: switch (_type) {
                      .webdav => const WebDavSettingPage(
                        showAppBar: false,
                      ),
                      .about => const AboutPage(showAppBar: false),
                      _ => CommonSetting(
                        settingType: _type,
                        showAppBar: false,
                      ),
                    },
                  ),
                ],
              ),
      ),
    );
  }

  @override
  void dispose() {
    _noAccount.close();
    super.dispose();
  }

  void _toPage(SettingType type) {
    if (_isPortrait) {
      Get.to(
        () => switch (type) {
          .webdav => const WebDavSettingPage(),
          .about => const AboutPage(),
          _ => CommonSetting(settingType: type),
        },
      );
    } else {
      _type = type;
      setState(() {});
    }
  }

  Color? _getTileColor(ThemeData theme, SettingType type) {
    if (_isPortrait) {
      return null;
    } else {
      return type == _type ? theme.colorScheme.onInverseSurface : null;
    }
  }

  Widget _buildList(ThemeData theme) {
    final padding = MediaQuery.viewPaddingOf(context);
    TextStyle titleStyle = theme.textTheme.titleMedium!;
    TextStyle subTitleStyle = theme.textTheme.labelMedium!.copyWith(
      color: theme.colorScheme.outline,
    );
    return ListView(
      padding: EdgeInsets.only(bottom: padding.bottom + 100),
      children: [
        _buildSearchItem(theme),
        ..._items
            .take(_items.length - 1)
            .map(
              (item) => ListTile(
                tileColor: _getTileColor(theme, item.type),
                onTap: () => _toPage(item.type),
                leading: item.icon,
                title: Text(item.type.title, style: titleStyle),
                subtitle: item.subtitle == null
                    ? null
                    : Text(item.subtitle!, style: subTitleStyle),
              ),
            ),
        ListTile(
          onTap: () => LoginPageController.switchAccountDialog(context),
          leading: const Icon(Icons.switch_account_outlined),
          title: Text('切换账号', style: titleStyle),
        ),
        Obx(
          () => _noAccount.value
              ? const SizedBox.shrink()
              : ListTile(
                  leading: const Icon(Icons.logout_outlined),
                  onTap: () => _logoutDialog(context),
                  title: Text('退出登录', style: titleStyle),
                ),
        ),
        ListTile(
          tileColor: _getTileColor(theme, _items.last.type),
          onTap: () => _toPage(_items.last.type),
          leading: _items.last.icon,
          title: Text(_items.last.type.title, style: titleStyle),
        ),
      ],
    );
  }

  Future<void> _removeAccounts(Set<LoginAccount> accounts) async {
    await Accounts.deleteAll(accounts);
    if (mounted) _noAccount.value = Accounts.account.isEmpty;
  }

  static Future<LoginAccount?> _logoutWrapper(LoginAccount account) async {
    try {
      final res = await LoginHttp.logout(account);
      return res.isSuccess ? account : null;
    } catch (e, s) {
      Utils.reportError(e, s);
      return null;
    }
  }

  Future<void> _logoutDialog(BuildContext context) async {
    final result = await showDialog<Set<LoginAccount>>(
      context: context,
      builder: (context) => MultiSelectDialog<LoginAccount>(
        title: '选择要登出的账号uid',
        initValues: const Iterable.empty(),
        values: {
          for (final i in Accounts.account.values) i: i.mid.toString(),
        },
      ),
    );
    if (!context.mounted || result == null || result.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('提示'),
          content: Text(
            "确认要退出以下账号登录吗\n\n${result.map((i) => i.mid).join('\n')}",
          ),
          actions: [
            TextButton(
              onPressed: Get.back,
              child: Text(
                '点错了',
                style: TextStyle(color: theme.colorScheme.outline),
              ),
            ),
            TextButton(
              onPressed: () {
                Get.back();
                _removeAccounts(result);
              },
              child: Text(
                '仅登出',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
            TextButton(
              onPressed: () async {
                SmartDialog.showLoading();
                final res = await Future.wait(result.map(_logoutWrapper));
                SmartDialog.dismiss();
                final logoutAccounts = res.nonNulls.toSet();
                if (logoutAccounts.isEmpty) {
                  SmartDialog.showToast('所选账号均退出登录失败');
                } else {
                  Get.back();
                  _removeAccounts(logoutAccounts);
                  if (logoutAccounts.length != result.length) {
                    result.removeWhere(logoutAccounts.contains);
                    SmartDialog.showToast(
                      '账号 ${result.map((i) => i.mid).join(",")} 退出登录失败',
                    );
                  }
                }
              },
              child: const Text('确认'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchItem(ThemeData theme) => Padding(
    padding: const EdgeInsets.only(
      left: 16,
      right: 16,
      bottom: 8,
    ),
    child: Material(
      color: theme.colorScheme.onInverseSurface,
      borderRadius: const BorderRadius.all(Radius.circular(50)),
      child: InkWell(
        onTap: () => Get.toNamed('/settingsSearch'),
        borderRadius: const BorderRadius.all(Radius.circular(50)),
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  size: 18,
                  applyTextScaling: true,
                  Icons.search,
                ),
                Text(
                  ' 搜索',
                  style: TextStyle(height: 1),
                  strutStyle: StrutStyle(height: 1, leading: 0),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
