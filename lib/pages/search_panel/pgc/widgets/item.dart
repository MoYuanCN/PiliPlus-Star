import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/badge.dart';
import 'package:PiliPlus/common/widgets/image/image_save.dart';
import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/models/search/result.dart';
import 'package:PiliPlus/utils/app_scheme.dart';
import 'package:PiliPlus/utils/date_utils.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:material_ui/material_ui.dart';

class SearchPgcItem extends StatelessWidget {
  const SearchPgcItem({super.key, required this.item, this.compact = false});

  final SearchPgcItemModel item;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    const TextStyle style = TextStyle(fontSize: 13);
    final fixedPubtime = item.fixPubtimeStr?.trim();
    final publishInfo = fixedPubtime?.isNotEmpty == true
        ? fixedPubtime
        : item.pubtime != null && item.pubtime! >= 946684800
        ? DateFormatUtils.dateFormat(item.pubtime)
        : null;
    final description = item.desc?.trim();
    final score = item.mediaScore?['score'];
    final scoreCount =
        item.mediaScore?['user_count'] ?? item.mediaScore?['vote'];
    final parsedScore = score is num ? score : num.tryParse('$score');
    final scoreValue = parsedScore != null && parsedScore > 0
        ? parsedScore.toStringAsFixed(1)
        : null;
    final parsedScoreCount = scoreCount is num
        ? scoreCount.toInt()
        : int.tryParse(scoreCount?.toString() ?? '');
    final scoreLine = [
      if (scoreValue?.isNotEmpty == true) '评分:$scoreValue',
      if (parsedScoreCount != null && parsedScoreCount > 0)
        '$parsedScoreCount人评分',
    ].join('  ·  ');
    Future<void> onTap() async {
      final gotoUrl = item.gotoUrl?.trim();
      if (gotoUrl?.isNotEmpty == true) {
        var normalizedUrl = gotoUrl!;
        if (normalizedUrl.startsWith('//')) {
          normalizedUrl = 'https:$normalizedUrl';
        } else if (!(Uri.tryParse(normalizedUrl)?.hasScheme ?? false)) {
          normalizedUrl = 'https://$normalizedUrl';
        }
        final uri = Uri.tryParse(normalizedUrl);
        final isBilibiliUrl =
            uri != null &&
            ((uri.scheme == 'bilibili' && uri.host == 'bangumi') ||
                uri.host == 'bilibili.com' ||
                uri.host.endsWith('.bilibili.com'));
        final isPgcUrl =
            isBilibiliUrl &&
            RegExp(
              r'(?:/bangumi/play/(?:ss|ep)\d+|bilibili://bangumi/season/\d+)',
              caseSensitive: false,
            ).hasMatch(normalizedUrl);
        if (isPgcUrl &&
            PageUtils.viewPgcFromUri(
              gotoUrl,
              resolverRegionCode: item.resolverRegionCode,
            )) {
          return;
        }
        await PiliScheme.routePushFromUrl(gotoUrl);
        return;
      }
      await PageUtils.viewPgc(
        seasonId: item.seasonId,
        resolverRegionCode: item.resolverRegionCode,
      );
    }

    void onLongPress() => imageSaveDialog(
      title: item.title.map((item) => item.text).join(),
      cover: item.cover,
    );
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        onSecondaryTap: PlatformUtils.isMobile ? null : onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Style.safeSpace,
            vertical: 5,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  NetworkImgLayer(
                    width: 111,
                    height: 148,
                    src: item.cover,
                    // Search covers can be arbitrary injected URLs. Keep the
                    // original extension and query string instead of adding a
                    // Bilibili thumbnail suffix (for example @1q.webp).
                    quality: 100,
                  ),
                  PBadge(
                    text: item.seasonTypeName,
                    top: 6.0,
                    right: 6.0,
                    bottom: null,
                    left: null,
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: item.title
                            .map(
                              (e) => TextSpan(
                                text: e.text,
                                style: TextStyle(
                                  color: e.isEm
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurface,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    if (scoreLine.isNotEmpty)
                      Text(
                        scoreLine,
                        style: style,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (item.areas?.isNotEmpty == true || publishInfo != null)
                      Text.rich(
                        style: style,
                        TextSpan(
                          children: [
                            if (item.areas?.isNotEmpty == true)
                              TextSpan(text: '${item.areas!}  ·  '),
                            if (publishInfo != null)
                              TextSpan(text: publishInfo),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (item.styles?.isNotEmpty == true ||
                        item.indexShow?.isNotEmpty == true)
                      Text.rich(
                        style: style,
                        TextSpan(
                          children: [
                            if (item.styles?.isNotEmpty == true)
                              TextSpan(text: '${item.styles!}  ·  '),
                            if (item.indexShow?.isNotEmpty == true)
                              TextSpan(text: item.indexShow!),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (item.episodeCount != null && item.episodeCount! > 0 ||
                        item.allNetName?.trim().isNotEmpty == true)
                      Text.rich(
                        style: style,
                        TextSpan(
                          children: [
                            if (item.episodeCount != null &&
                                item.episodeCount! > 0)
                              TextSpan(text: '${item.episodeCount}集'),
                            if (item.episodeCount != null &&
                                item.episodeCount! > 0 &&
                                item.allNetName?.trim().isNotEmpty == true)
                              const TextSpan(text: '  ·  '),
                            if (item.allNetName?.trim().isNotEmpty == true)
                              TextSpan(text: item.allNetName!.trim()),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (!compact && item.badgeTexts.isNotEmpty)
                      Text(
                        item.badgeTexts.join('  ·  '),
                        style: style,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (!compact && item.label?.trim().isNotEmpty == true)
                      Text(
                        item.label!.trim(),
                        style: style,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (!compact && item.cv?.trim().isNotEmpty == true)
                      Text(
                        'CV：${item.cv!.trim()}',
                        style: style,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (!compact && item.staff?.trim().isNotEmpty == true)
                      Text(
                        '制作：${item.staff!.trim()}',
                        style: style,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (description?.isNotEmpty == true)
                      Flexible(
                        fit: FlexFit.loose,
                        child: Text(
                          description!,
                          style: style.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
