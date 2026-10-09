import 'dart:async' show StreamSubscription, Timer, unawaited;

import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/search.dart';
import 'package:PiliPlus/models/common/search/article_search_type.dart';
import 'package:PiliPlus/models/common/search/search_type.dart';
import 'package:PiliPlus/models/common/search/user_search_type.dart';
import 'package:PiliPlus/models/common/search/video_search_type.dart';
import 'package:PiliPlus/models/search/result.dart';
import 'package:PiliPlus/pages/common/common_list_controller.dart';
import 'package:PiliPlus/pages/search_result/controller.dart';
import 'package:PiliPlus/utils/extension/scroll_controller_ext.dart';
import 'package:PiliPlus/utils/bangumi_resolver.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

class SearchPanelController<R extends SearchNumData<T>, T>
    extends CommonListController<R, T> {
  SearchPanelController({
    required this.keyword,
    required this.searchType,
    required this.tag,
  });
  final String tag;
  final String keyword;
  final SearchType searchType;
  SearchType get searchType_ => searchType;

  // sort
  // common
  String order = '';

  // video
  VideoDurationType? videoDurationType; // int duration
  VideoZoneType? videoZoneType; // int? tids;
  int? pubBegin;
  int? pubEnd;

  // user
  Rx<UserOrderType>? userOrderType;
  Rx<UserType>? userType;

  // article
  Rx<ArticleZoneType>? articleZoneType; // int? categoryId;

  SearchResultController? searchResultController;

  void onSortSearch({bool getBack = true, String? label}) {
    if (getBack) Get.back();
    SmartDialog.dismiss();
    if (label != null) {
      SmartDialog.showToast("「$label」的筛选结果");
    }
    SmartDialog.showLoading(msg: 'loading');
    onReload().whenComplete(SmartDialog.dismiss);
  }

  StreamSubscription? _listener;

  void cancelListener() {
    _listener?.cancel();
  }

  @override
  void onInit() {
    super.onInit();
    try {
      searchResultController = Get.find<SearchResultController>(tag: tag);
      _listener = searchResultController!.toTopIndex.listen((index) {
        if (index == searchType.index) {
          scrollController.animToTop();
        }
      });
    } catch (_) {}
    queryData();
    if ((searchType == SearchType.media_bangumi ||
            searchType == SearchType.media_ft) &&
        BangumiRegion.configured.isNotEmpty) {
      unawaited(_prefetchResolverRegions());
    }
  }

  @override
  List<T>? getDataList(R response) {
    return response.list;
  }

  @override
  bool customHandleResponse(bool isRefresh, Success<R> response) {
    if (isRefresh) {
      searchResultController?.count[searchType.index] =
          response.response.numResults ?? 0;
    }
    return false;
  }

  String? gaiaVtoken;
  final Rxn<BangumiRegion> resolverRegion = Rxn<BangumiRegion>();
  String? _resolverCursor;
  int _resolverRequestGeneration = 0;
  final _regionRequests =
      <
        ({BangumiRegion region, int page}),
        Future<LoadingState<SearchPgcData>>
      >{};
  final _regionHasMore = <BangumiRegion, bool>{};
  final _regionCursors = <BangumiRegion, String?>{};

  bool get _usesIntlAppSearch =>
      searchType == SearchType.media_bangumi &&
      resolverRegion.value == BangumiRegion.sea;

  Future<void> selectResolverRegion(BangumiRegion? region) async {
    if (resolverRegion.value == region) return;
    _resolverRequestGeneration++;
    resolverRegion.value = region;
    _resolverCursor = null;
    page = 1;
    isEnd = false;
    loadingState.value = LoadingState<List<T>?>.loading();
    await queryDataSuperseding();
  }

  Future<void> _prefetchResolverRegions() async {
    final regions = BangumiRegion.configured.where(
      (region) =>
          searchType != SearchType.media_ft || region != BangumiRegion.sea,
    );
    await Future.wait(
      regions.map((region) async {
        try {
          await _regionPage(region, 1);
        } catch (_) {}
      }),
    );
  }

  Future<LoadingState<SearchPgcData>> _regionPage(
    BangumiRegion region,
    int requestedPage,
  ) {
    final key = (region: region, page: requestedPage);
    return _regionRequests.putIfAbsent(key, () async {
      final result = await SearchHttp.searchByType<SearchPgcData>(
        searchType: searchType,
        keyword: keyword,
        page: requestedPage,
        order: order,
        duration: videoDurationType?.index,
        tids: videoZoneType?.tids,
        orderSort: userOrderType?.value.orderSort,
        userType: userType?.value.index,
        categoryId: articleZoneType?.value.categoryId,
        pubBegin: pubBegin,
        pubEnd: pubEnd,
        resolverRegion: region,
        resolverCursor: region == BangumiRegion.sea
            ? _regionCursors[region]
            : null,
        onSuccess: (_) {},
      );
      if (result is Success<SearchPgcData>) {
        _regionCursors[region] = result.response.nextCursor;
        _regionHasMore[region] = region == BangumiRegion.sea
            ? result.response.nextCursor?.isNotEmpty == true
            : (result.response.numResults ?? 0) > requestedPage * 20;
      }
      return result;
    });
  }

  @override
  Future<LoadingState<R>> customGetData() async {
    final requestGeneration = _resolverRequestGeneration;
    final requestedPage = page;
    final requestedRegion = resolverRegion.value;
    final useIntlAppSearch =
        searchType == SearchType.media_bangumi &&
        requestedRegion == BangumiRegion.sea;
    final requestedCursor = useIntlAppSearch ? _resolverCursor : null;
    if (requestedRegion != null &&
        (searchType == SearchType.media_bangumi ||
            searchType == SearchType.media_ft)) {
      final result = await _regionPage(requestedRegion, requestedPage);
      if (requestGeneration != _resolverRequestGeneration) {
        return result as LoadingState<R>;
      }
      if (result is Success<SearchPgcData> && result.response.list != null) {
        final seen = <String>{};
        if (requestedPage > 1) {
          final current = loadingState.value;
          if (current is Success<List<T>?>) {
            for (final value in current.response ?? <T>[]) {
              if (value is SearchPgcItemModel) {
                final key = _pgcResultKey(value);
                if (key != null) seen.add(key);
              }
            }
          }
        }
        result.response.list!.removeWhere((item) {
          final key = _pgcResultKey(item);
          if (item.isResolverInjected && key == null) return true;
          return key != null && !seen.add(key);
        });
      }
      return result as LoadingState<R>;
    }
    final result = await SearchHttp.searchByType<R>(
      searchType: searchType_,
      keyword: keyword,
      page: requestedPage,
      order: order,
      duration: videoDurationType?.index,
      tids: videoZoneType?.tids,
      orderSort: userOrderType?.value.orderSort,
      userType: userType?.value.index,
      categoryId: articleZoneType?.value.categoryId,
      pubBegin: pubBegin,
      pubEnd: pubEnd,
      gaiaVtoken: gaiaVtoken,
      resolverRegion: requestedRegion,
      resolverCursor: requestedCursor,
      onSuccess: (String gaiaVtoken) {
        if (requestGeneration != _resolverRequestGeneration) return;
        this.gaiaVtoken = gaiaVtoken;
        Timer(const Duration(milliseconds: 200), () {
          if (!isClosed && requestGeneration == _resolverRequestGeneration) {
            queryData(requestedPage == 1);
          }
        });
      },
    );
    if (requestGeneration != _resolverRequestGeneration) return result;
    if (result is Success<R> && result.response is SearchPgcData) {
      final response = result.response as SearchPgcData;
      _resolverCursor = response.nextCursor;
      if (requestedRegion != null && response.list != null) {
        final current = loadingState.value;
        final previous = requestedPage > 1 && current is Success<List<T>?>
            ? current.response ?? <T>[]
            : <T>[];
        final seen = <String>{};
        for (final value in previous) {
          if (value is SearchPgcItemModel) {
            final key = _pgcResultKey(value);
            if (key != null) seen.add(key);
          }
        }
        response.list!.removeWhere((item) {
          final key = _pgcResultKey(item);
          if (item.isResolverInjected && key == null) return true;
          return key != null && !seen.add(key);
        });
      }
    }
    return result;
  }

  String? _pgcResultKey(SearchPgcItemModel item) {
    final link =
        (item.gotoUrl?.trim().isNotEmpty == true ? item.gotoUrl : item.url)
            ?.trim();
    final title = item.title.map((part) => part.text).join().trim();
    final cover = item.cover?.trim().toLowerCase() ?? '';
    final area = item.areas?.trim().toLowerCase() ?? '';
    if (item.isResolverInjected) {
      if (link?.isNotEmpty == true) {
        return 'injected:${link!.toLowerCase()}|${title.toLowerCase()}|$cover';
      }
      if (title.isEmpty) return null;
      return 'injected:${title.toLowerCase()}|$area|$cover';
    }
    if (item.seasonId != null && item.seasonId! > 0) {
      return 'season:${item.seasonId}';
    }
    if (item.mediaId != null && item.mediaId! > 0) {
      return 'media:${item.mediaId}';
    }
    if (link?.isNotEmpty == true) return 'url:${link!.toLowerCase()}';
    if (title.isEmpty) return null;
    return 'title:${title.toLowerCase()}|$area|$cover';
  }

  @override
  void checkIsEnd(int length) {
    if (resolverRegion.value != null &&
        _regionHasMore[resolverRegion.value] != true) {
      isEnd = true;
    } else if (_usesIntlAppSearch && _resolverCursor?.isNotEmpty != true) {
      isEnd = true;
    }
  }

  void _clearRegionRequests() {
    _regionRequests.clear();
    _regionHasMore.clear();
    _regionCursors.clear();
  }

  @override
  Future<void> onRefresh() {
    _resolverCursor = null;
    _clearRegionRequests();
    return super.onRefresh();
  }

  @override
  Future<void> onReload() {
    _resolverCursor = null;
    _clearRegionRequests();
    scrollController.jumpToTop();
    return super.onReload();
  }
}
