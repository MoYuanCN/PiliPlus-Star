import 'package:PiliPlus/common/skeleton/media_bangumi.dart';
import 'package:PiliPlus/common/sliver_single_child_delegate.dart';
import 'package:PiliPlus/models/search/result.dart';
import 'package:PiliPlus/pages/search_panel/controller.dart';
import 'package:PiliPlus/pages/search_panel/pgc/widgets/item.dart';
import 'package:PiliPlus/pages/search_panel/view.dart';
import 'package:PiliPlus/utils/grid.dart';
import 'package:PiliPlus/utils/bangumi_resolver.dart';
import 'package:get/get.dart';
import 'package:material_ui/material_ui.dart'
    hide SliverGridDelegateWithMaxCrossAxisExtent;

class SearchPgcPanel extends CommonSearchPanel {
  const SearchPgcPanel({
    super.key,
    required super.keyword,
    required super.tag,
    required super.searchType,
  });

  @override
  State<SearchPgcPanel> createState() => _SearchPgcPanelState();
}

class _SearchPgcPanelState
    extends
        CommonSearchPanelState<
          SearchPgcPanel,
          SearchPgcData,
          SearchPgcItemModel
        > {
  @override
  late final SearchPanelController<SearchPgcData, SearchPgcItemModel>
  controller;

  @override
  void initState() {
    super.initState();
    controller = Get.put(
      SearchPanelController<SearchPgcData, SearchPgcItemModel>(
        keyword: widget.keyword,
        searchType: widget.searchType,
        tag: widget.tag,
      ),
      tag: widget.searchType.name + widget.tag,
    );
  }

  late final gridDelegate = SliverGridDelegateWithMaxCrossAxisExtent(
    maxCrossAxisExtent: Grid.smallCardWidth * 2,
    mainAxisExtent: 158,
  );

  @override
  Widget? buildHeader() {
    if (!{'media_bangumi', 'media_ft'}.contains(widget.searchType.name) ||
        !BangumiRegion.enabled ||
        BangumiRegion.configured.isEmpty) {
      return null;
    }
    return SliverToBoxAdapter(
      child: Obx(
        () => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('B站'),
                selected: controller.resolverRegion.value == null,
                onSelected: (_) => controller.selectResolverRegion(null),
              ),
              for (final region in BangumiRegion.configured.where(
                (region) =>
                    widget.searchType.name == 'media_bangumi' ||
                    region != BangumiRegion.sea,
              )) ...[
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text('番剧（${region.label}）'),
                  selected: controller.resolverRegion.value == region,
                  onSelected: (_) => controller.selectResolverRegion(region),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget buildList(List<SearchPgcItemModel> list) {
    return SliverGrid.builder(
      gridDelegate: gridDelegate,
      itemBuilder: (BuildContext context, int index) {
        if (index == list.length - 1) {
          controller.onLoadMore();
        }
        return SearchPgcItem(item: list[index]);
      },
      itemCount: list.length,
    );
  }

  @override
  Widget get buildLoading => SliverGrid(
    gridDelegate: gridDelegate,
    delegate: const SliverSingleChildDelegate(
      count: 10,
      child: MediaPgcSkeleton(),
    ),
  );
}
