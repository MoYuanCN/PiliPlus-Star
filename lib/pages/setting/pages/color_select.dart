import 'dart:io' show Platform;

import 'package:PiliPlus/common/widgets/animated_height.dart';
import 'package:PiliPlus/common/widgets/color_palette.dart';
import 'package:PiliPlus/common/widgets/scaffold/simple_scaffold.dart';
import 'package:PiliPlus/main.dart' show MyApp;
import 'package:PiliPlus/models/common/nav_bar_config.dart';
import 'package:PiliPlus/models/common/theme/theme_color_type.dart';
import 'package:PiliPlus/models/common/theme/theme_type.dart';
import 'package:PiliPlus/pages/home/view.dart';
import 'package:PiliPlus/pages/mine/controller.dart';
import 'package:PiliPlus/pages/setting/slide_color_picker.dart';
import 'package:PiliPlus/pages/setting/widgets/popup_item.dart';
import 'package:PiliPlus/pages/setting/widgets/select_dialog.dart';
import 'package:PiliPlus/utils/extension/get_ext.dart';
import 'package:PiliPlus/utils/extension/theme_ext.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:PiliPlus/utils/theme_utils.dart';
import 'package:collection/collection.dart';
import 'package:flex_seed_scheme/flex_seed_scheme.dart';
import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart';

class ColorSelectPage extends StatefulWidget {
  const ColorSelectPage({super.key});

  @override
  State<ColorSelectPage> createState() => _ColorSelectPageState();
}

class Item {
  Item({
    required this.expandedValue,
    required this.headerValue,
    this.isExpanded = false,
  });

  String expandedValue;
  String headerValue;
  bool isExpanded;
}

class _ColorSelectPageState extends State<ColorSelectPage> {
  final ctr = Get.put(_ColorSelectController());
  FlexSchemeVariant _dynamicSchemeVariant = Pref.schemeVariant;

  Future<void> _onChanged([bool? val]) async {
    val ??= !ctr.dynamicColor.value;
    if (val && !await MyApp.initPlatformState()) {
      SmartDialog.showToast('设备可能不支持动态取色');
      if (kReleaseMode) {
        return;
      }
    }
    ctr.dynamicColor.value = val;
    await GStorage.setting.put(SettingBoxKey.dynamicColor, val);
    Get.updateMyAppTheme();
  }

  Future<void> _refreshWallpaperColors() async {
    final supported = await MyApp.refreshPlatformColors();
    if (!mounted) return;
    if (supported) {
      Get.updateMyAppTheme();
      SmartDialog.showToast('已更新系统壁纸颜色');
    } else {
      SmartDialog.showToast('设备未提供系统动态颜色');
    }
  }

  late ThemeData theme;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    theme = Theme.of(context);
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = theme.textTheme.titleMedium!;
    final subTitleStyle = theme.textTheme.labelMedium!.copyWith(
      color: theme.colorScheme.outline,
    );
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.viewPaddingOf(
      context,
    ).copyWith(top: 0, bottom: 0);
    return SimpleScaffold(
      appBar: AppBar(title: const Text('选择应用主题')),
      body: ListView(
        padding: .only(
          bottom: MediaQuery.viewPaddingOf(context).bottom + 100,
        ),
        children: [
          ListTile(
            onTap: () async {
              final result = await showDialog<ThemeType>(
                context: context,
                builder: (context) => SelectDialog<ThemeType>(
                  title: '主题模式',
                  value: ctr.themeType.value,
                  values: ThemeType.values.map((e) => (e, e.label)).toList(),
                ),
              );
              if (result != null) {
                try {
                  Get.find<MineController>().themeType.value = result;
                } catch (_) {}
                ctr.themeType.value = result;
                GStorage.setting.put(SettingBoxKey.themeMode, result.index);
                Get.changeThemeMode(ThemeUtils.themeMode = result.toThemeMode);
              }
            },
            leading: const Icon(Icons.flashlight_on_outlined),
            title: Text('主题模式', style: titleStyle),
            subtitle: Obx(
              () => Text(
                '当前模式：${ctr.themeType.value.label}',
                style: subTitleStyle,
              ),
            ),
          ),
          Obx(
            () => PopupListTile<FlexSchemeVariant>(
              enabled: !ctr.dynamicColor.value,
              leading: const Icon(Icons.palette_outlined),
              title: const Text('调色板风格'),
              value: () =>
                  (_dynamicSchemeVariant, _dynamicSchemeVariant.variantName),
              itemBuilder: (_) => FlexSchemeVariant.values
                  .map(
                    (e) => PopupMenuItem(value: e, child: Text(e.variantName)),
                  )
                  .toList(),
              onSelected: (value, setState) {
                _dynamicSchemeVariant = value;
                GStorage.setting
                    .put(SettingBoxKey.schemeVariant, value.index)
                    .whenComplete(Get.updateMyAppTheme);
              },
            ),
          ),
          if (!Platform.isIOS)
            Obx(
              () => ListTile(
                title: const Text('系统动态颜色（Monet）'),
                subtitle: const Text('Android 12 及以上可读取系统壁纸调色板'),
                leading: ExcludeFocus(
                  child: Checkbox(
                    value: ctr.dynamicColor.value,
                    onChanged: _onChanged,
                    materialTapTargetSize: .shrinkWrap,
                    visualDensity: const .new(horizontal: -4, vertical: -4),
                  ),
                ),
                onTap: _onChanged,
              ),
            ),
          if (Platform.isAndroid)
            Obx(
              () => ListTile(
                enabled: ctr.dynamicColor.value,
                onTap: _refreshWallpaperColors,
                leading: const Icon(Icons.refresh),
                title: const Text('重新读取系统壁纸颜色'),
                subtitle: const Text('更换壁纸后可手动刷新配色'),
                trailing: const Icon(Icons.chevron_right),
              ),
            ),
          Padding(
            padding: padding + const .all(12),
            child: Obx(_buildColorPanel),
          ),
          Padding(
            padding: padding,
            child: ExcludeFocus(
              child: IgnorePointer(
                child: Container(
                  height: size.height / 2,
                  width: size.width,
                  color: theme.colorScheme.surface,
                  child: const HomePage(),
                ),
              ),
            ),
          ),
          ExcludeFocus(
            child: IgnorePointer(
              child: NavigationBar(
                destinations: NavigationBarType.values
                    .map(
                      (item) => NavigationDestination(
                        icon: item.icon,
                        label: item.label,
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorPanel() {
    final currentColor = ctr.currentColor.value;
    final currentSeed =
        currentColor >= 0 && currentColor < colorThemeTypes.length
        ? colorThemeTypes[currentColor].color
        : Color(currentColor);
    return AnimatedHeightWidgetExt(
      expand: !ctr.dynamicColor.value,
      duration: const Duration(milliseconds: 200),
      child: Wrap(
        spacing: 22,
        runSpacing: 18,
        alignment: .center,
        children: [
          GestureDetector(
            behavior: .opaque,
            onTap: () async {
              final raw = currentSeed.toARGB32();
              if (ctr.customColors.contains(raw)) {
                SmartDialog.showToast('这个颜色已收藏');
                return;
              }
              ctr.customColors.add(raw);
              await GStorage.setting.put(
                SettingBoxKey.customThemeColors,
                ctr.customColors.toList(),
              );
              SmartDialog.showToast('已收藏主题色');
            },
            child: Column(
              spacing: 3,
              children: [
                Icon(
                  Icons.bookmark_add_outlined,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
                Text('收藏当前色', style: theme.textTheme.labelSmall),
              ],
            ),
          ),
          Builder(
            builder: (context) {
              final isCurr = currentColor > colorThemeTypes.length;
              final color = isCurr
                  ? Color(currentColor)
                  : colorThemeTypes[currentColor].color;
              return GestureDetector(
                behavior: .opaque,
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      clipBehavior: .hardEdge,
                      contentPadding: const .symmetric(vertical: 16),
                      title: const Text('Color Picker'),
                      content: SlideColorPicker(
                        color: color,
                        onChanged: (Color? color) {
                          if (color != null) {
                            final res = color.toARGB32();
                            ctr.currentColor.value = res;
                            GStorage.setting
                                .put(SettingBoxKey.customColor, res)
                                .whenComplete(Get.updateMyAppTheme);
                          }
                        },
                      ),
                    ),
                  );
                },
                child: Column(
                  spacing: 3,
                  children: [
                    ColorPalette(
                      colorScheme: color.asColorSchemeSeed(
                        _dynamicSchemeVariant,
                        theme.brightness,
                      ),
                      selected: isCurr,
                    ),
                    Text(
                      '自定义',
                      style: TextStyle(
                        fontSize: 12,
                        color: isCurr
                            ? null
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          ...ctr.customColors.mapIndexed((index, value) {
            final color = Color(value);
            final isCurr = currentColor == value;
            return GestureDetector(
              behavior: .opaque,
              onTap: () {
                ctr.currentColor.value = value;
                GStorage.setting
                    .put(SettingBoxKey.customColor, value)
                    .whenComplete(Get.updateMyAppTheme);
              },
              onLongPress: () async {
                ctr.customColors.removeAt(index);
                await GStorage.setting.put(
                  SettingBoxKey.customThemeColors,
                  ctr.customColors.toList(),
                );
                SmartDialog.showToast('已移除收藏颜色');
              },
              child: Column(
                spacing: 3,
                children: [
                  ColorPalette(
                    colorScheme: color.asColorSchemeSeed(
                      _dynamicSchemeVariant,
                      theme.brightness,
                    ),
                    selected: isCurr,
                  ),
                  Text(
                    '#${(value & 0xFFFFFF).toRadixString(16).toUpperCase().padLeft(6)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isCurr ? null : theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            );
          }),
          ...colorThemeTypes.mapIndexed(
            (i, e) {
              final color = e.color;
              final isCurr = currentColor == i;
              return GestureDetector(
                behavior: .opaque,
                onTap: () {
                  ctr.currentColor.value = i;
                  GStorage.setting
                      .put(SettingBoxKey.customColor, i)
                      .whenComplete(Get.updateMyAppTheme);
                },
                child: Column(
                  spacing: 3,
                  children: [
                    ColorPalette(
                      colorScheme: color.asColorSchemeSeed(
                        _dynamicSchemeVariant,
                        theme.brightness,
                      ),
                      selected: isCurr,
                    ),
                    Text(
                      e.label,
                      style: TextStyle(
                        fontSize: 12,
                        color: isCurr ? null : theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ColorSelectController extends GetxController {
  final RxBool dynamicColor = Pref.dynamicColor.obs;
  final RxInt currentColor = Pref.customColor.obs;
  final RxList<int> customColors = Pref.customThemeColors.obs;
  final Rx<ThemeType> themeType = Pref.themeType.obs;
}
