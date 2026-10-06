import 'package:PiliPlus/http/constants.dart';
import 'package:PiliPlus/models/horizontal_video_model.dart';
import 'package:PiliPlus/models/model_avatar.dart';
import 'package:PiliPlus/models/model_owner.dart';
import 'package:PiliPlus/models/model_video.dart';
import 'package:PiliPlus/models/search/search_esports.dart';
import 'package:PiliPlus/utils/duration_utils.dart';
import 'package:PiliPlus/utils/em.dart';
import 'package:PiliPlus/utils/extension/iterable_ext.dart';
import 'package:PiliPlus/utils/global_data.dart';
import 'package:PiliPlus/utils/parse_int.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

abstract class SearchNumData<T> {
  SearchNumData({this.numResults, this.list});

  int? numResults;
  List<T>? list;
}

class SearchVideoData extends SearchNumData<SearchVideoItemModel> {
  SearchVideoData({super.numResults, super.list});

  SearchVideoData.fromJson(Map<String, dynamic> json) {
    numResults = (json['numResults'] as num?)?.toInt();
    list = (json['result'] as List?)
        ?.whereNotBlocked((e) => e['mid'])
        .map((e) => SearchVideoItemModel.fromJson(e))
        .toList();
  }

  List<SearchUser>? searchUser;
  List<SearchPgcItemModel>? searchMedia;
  List<SearchActivity>? searchActivity;
  SearchEsports? searchEsports;

  SearchVideoData.fromSearchAll(Map<String, dynamic> json) {
    numResults = (json['numResults'] as num?)?.toInt();
    if (json['result'] case List result when result.isNotEmpty) {
      for (final item in result) {
        switch (item['result_type']) {
          case 'video':
            list = (item['data'] as List?)
                ?.whereNotBlocked((e) => e['mid'])
                .map((e) => SearchVideoItemModel.fromJson(e))
                .toList();
          case 'bili_user':
            if (item['data'] case List users when users.isNotEmpty) {
              for (final e in users) {
                if (!GlobalData().blackMids.contains(e['mid'])) {
                  (searchUser ??= <SearchUser>[]).add(SearchUser.fromJson(e));
                }
              }
            }
          case 'media_bangumi' || 'media_ft':
            if (item['data'] case List medias when medias.isNotEmpty) {
              (searchMedia ??= <SearchPgcItemModel>[]).addAll(
                medias.map((e) => SearchPgcItemModel.fromJson(e)),
              );
            }
          case 'activity':
            if (item['data'] case List activities when activities.isNotEmpty) {
              for (final e in activities) {
                if (e['url'] case final String url
                    when url.startsWith(HttpString.liveUrl)) {
                  final model = SearchActivity.fromJson(e, url);
                  (searchActivity ??= <SearchActivity>[]).add(model);
                }
              }
            }
          case 'esports':
            if (item['data'] case List esports when esports.isNotEmpty) {
              try {
                searchEsports = SearchEsports.fromJson(esports.first);
              } catch (_) {
                if (kDebugMode) rethrow;
              }
            }
        }
      }
    }
  }
}

class SearchActivity {
  int? id;
  String? title;
  String? desc;
  String? cover;
  String url;
  int? state;
  int? status;
  String? author;

  SearchActivity({
    this.id,
    this.title,
    this.desc,
    this.cover,
    required this.url,
    this.state,
    this.status,
    this.author,
  });

  factory SearchActivity.fromJson(Map<String, dynamic> json, String url) {
    return SearchActivity(
      id: json['id'] as int?,
      title: json['title'] as String?,
      desc: json['desc'] as String?,
      cover: json['cover'] as String?,
      url: url,
      state: json['state'] as int?,
      status: json['status'] as int?,
      author: json['author'] as String?,
    );
  }
}

class SearchUser {
  int? mid;
  String? uname;
  String? usign;
  int? fans;
  int? videos;
  String? upic;
  String? verifyInfo;
  int? level;
  int? gender;
  int? isUpuser;
  int? isLive;
  int? roomId;
  List<SearchVideoItemModel>? res;
  BaseOfficialVerify? officialVerify;
  int? isSeniorMember;

  SearchUser({
    this.mid,
    this.uname,
    this.usign,
    this.fans,
    this.videos,
    this.upic,
    this.verifyInfo,
    this.level,
    this.gender,
    this.isUpuser,
    this.isLive,
    this.roomId,
    this.res,
    this.officialVerify,
    this.isSeniorMember,
  });

  factory SearchUser.fromJson(Map<String, dynamic> json) => SearchUser(
    mid: json['mid'] as int?,
    uname: json['uname'] as String?,
    usign: json['usign'] as String?,
    fans: json['fans'] as int?,
    videos: json['videos'] as int?,
    upic: json['upic'] as String?,
    verifyInfo: json['verify_info'] as String?,
    level: json['level'] as int?,
    gender: json['gender'] as int?,
    isUpuser: json['is_upuser'] as int?,
    isLive: json['is_live'] as int?,
    roomId: json['room_id'] as int?,
    res: (json['res'] as List<dynamic>?)
        ?.map((e) => SearchVideoItemModel.fromJson(e as Map<String, dynamic>))
        .toList(),
    officialVerify: json['official_verify'] == null
        ? null
        : BaseOfficialVerify.fromJson(
            json['official_verify'] as Map<String, dynamic>,
          ),
    isSeniorMember: json['is_senior_member'] as int?,
  );
}

class SearchVideoItemModel extends HorizontalVideoModel {
  int? id;
  String? arcurl;
  String? tag;
  int? ctime;

  @override
  int? get seasonId => aid;

  SearchVideoItemModel.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    arcurl = json['arcurl'];
    aid = json['aid'];
    bvid = json['bvid'];
    titleList = Em.regTitle(json['title']);
    title = titleList!.map((i) => i.text).join();
    desc = json['description'];
    cover = json['pic'];
    pubdate = json['pubdate'];
    ctime = json['senddate'];
    duration = DurationUtils.parseDuration(json['duration']);
    owner = SearchOwner.fromJson(json);
    stat = SearchStat.fromJson(json);
    switch (json['type']) {
      case 'ketang':
        badge = '课堂';
        isPugv = true;
      case 'live_room':
        badge = '直播';
        isLive = true;
        roomId = json['roomid'];
      default:
        if (json['is_union_video'] == 1) {
          badge = '合作';
        }
    }
  }
}

class SearchStat extends BaseStat {
  // 收藏数
  int? favorite;
  // 评论数
  int? reply;

  SearchStat.fromJson(Map<String, dynamic> json) {
    view = safeToInt(json['play']);
    danmu = safeToInt(json['danmaku']);
    favorite = safeToInt(json['favorite']);
    reply = safeToInt(json['review']);
    like = safeToInt(json['like']);
  }
}

class SearchOwner extends Owner {
  SearchOwner.fromJson(Map<String, dynamic> json) {
    mid = json["mid"];
    name = json["author"];
    face = json['upic'];
  }
}

class SearchUserData extends SearchNumData<SearchUserItemModel> {
  SearchUserData({super.numResults, super.list});

  SearchUserData.fromJson(Map<String, dynamic> json) {
    numResults = (json['numResults'] as num?)?.toInt();
    list = (json['result'] as List?)
        ?.whereNotBlocked((e) => e['mid'])
        .map<SearchUserItemModel>((e) => SearchUserItemModel.fromJson(e))
        .toList();
  }
}

class SearchUserItemModel {
  SearchUserItemModel({
    this.type,
    this.mid,
    this.uname,
    this.usign,
    this.fans,
    this.videos,
    this.upic,
    this.faceNft,
    this.faceNftType,
    this.verifyInfo,
    this.level,
    this.gender,
    this.isUpUser,
    this.isLive,
    this.roomId,
    this.officialVerify,
    this.isSeniorMember,
  });

  String? type;
  int? mid;
  String? uname;
  String? usign;
  int? fans;
  int? videos;
  String? upic;
  int? faceNft;
  int? faceNftType;
  String? verifyInfo;
  int? level;
  int? gender;
  int? isUpUser;
  int? isLive;
  int? roomId;
  BaseOfficialVerify? officialVerify;
  int? isSeniorMember;

  SearchUserItemModel.fromJson(Map<String, dynamic> json) {
    type = json['type'];
    mid = json['mid'];
    uname = json['uname'];
    usign = json['usign'];
    fans = json['fans'];
    videos = json['videos'];
    upic = json['upic'];
    faceNft = json['face_nft'];
    faceNftType = json['face_nft_type'];
    verifyInfo = json['verify_info'];
    level = json['level'];
    gender = json['gender'];
    isUpUser = json['is_upuser'];
    isLive = json['is_live'];
    roomId = json['room_id'];
    officialVerify = json['official_verify'] == null
        ? null
        : BaseOfficialVerify.fromJson(json['official_verify']);
    isSeniorMember = json['is_senior_member'];
  }
}

class SearchLiveData extends SearchNumData<SearchLiveItemModel> {
  SearchLiveData({super.numResults, super.list});

  SearchLiveData.fromJson(Map<String, dynamic> json) {
    numResults = (json['numResults'] as num?)?.toInt();
    list = (json['result'] as List?)
        ?.whereNotBlocked((e) => e['uid'])
        .map((e) => SearchLiveItemModel.fromJson(e))
        .toList();
  }
}

class SearchLiveItemModel {
  SearchLiveItemModel({
    this.rankOffset,
    this.uid,
    this.tags,
    this.liveTime,
    this.uname,
    this.uface,
    this.face,
    this.userCover,
    this.type,
    required this.title,
    this.cover,
    this.pic,
    this.online,
    this.rankIndex,
    this.rankScore,
    this.roomid,
    this.attentions,
    this.cateName,
  });

  int? rankOffset;
  int? uid;
  String? tags;
  String? liveTime;
  String? uname;
  String? uface;
  String? face;
  String? userCover;
  String? type;
  late List<({bool isEm, String text})> title;
  String? cover;
  String? pic;
  int? online;
  int? rankIndex;
  int? rankScore;
  int? roomid;
  int? attentions;
  String? cateName;
  Map? watchedShow;

  SearchLiveItemModel.fromJson(Map<String, dynamic> json) {
    rankOffset = json['rank_offset'];
    uid = json['uid'];
    tags = json['tags'];
    liveTime = json['live_time'];
    uname = json['uname'];
    uface = json['uface'];
    face = json['uface'];
    userCover = json['user_cover'];
    type = json['type'];
    title = Em.regTitle(json['title']);
    cover = json['cover'];
    pic = json['cover'];
    online = json['online'];
    rankIndex = json['rank_index'];
    rankScore = json['rank_score'];
    roomid = json['roomid'];
    attentions = json['attentions'];
    cateName = Em.regCate(json['cate_name']);
  }
}

class SearchPgcData extends SearchNumData<SearchPgcItemModel> {
  SearchPgcData({super.numResults, super.list, this.nextCursor});

  String? nextCursor;

  SearchPgcData.fromJson(Map<String, dynamic> json) {
    numResults = (json['numResults'] as num?)?.toInt();
    nextCursor = (json['next'] ?? json['next_cursor'])?.toString();
    list = (json['result'] as List?)
        ?.map<SearchPgcItemModel>((e) => SearchPgcItemModel.fromJson(e))
        .toList();
  }
}

class SearchPgcItemModel {
  SearchPgcItemModel({
    this.type,
    this.mediaId,
    required this.title,
    this.orgTitle,
    this.mediaType,
    this.cv,
    this.staff,
    this.seasonId,
    this.isAvid,
    this.hitEpids,
    this.seasonType,
    this.seasonTypeName,
    this.url,
    this.buttonText,
    this.isFollow,
    this.isSelection,
    this.cover,
    this.areas,
    this.styles,
    this.gotoUrl,
    this.desc,
    this.pubtime,
    this.fixPubtimeStr,
    this.mediaMode,
    this.mediaScore,
    this.indexShow,
    this.episodeCount,
    this.allNetName,
    this.label,
    this.badgeTexts = const [],
    this.isResolverInjected = false,
  });

  String? type;
  int? mediaId;
  late List<({bool isEm, String text})> title;
  String? orgTitle;
  int? mediaType;
  String? cv;
  String? staff;
  int? seasonId;
  bool? isAvid;
  String? hitEpids;
  int? seasonType;
  String? seasonTypeName;
  String? url;
  String? buttonText;
  int? isFollow;
  int? isSelection;
  String? cover;
  String? areas;
  String? styles;
  String? gotoUrl;
  String? desc;
  int? pubtime;
  String? fixPubtimeStr;
  int? mediaMode;
  Map? mediaScore;
  String? indexShow;
  int? episodeCount;
  String? allNetName;
  String? label;
  late List<String> badgeTexts;
  String? resolverRegionCode;
  late bool isResolverInjected;

  static int? _intValue(dynamic value) => switch (value) {
    final int number => number,
    final num number => number.toInt(),
    final String text => int.tryParse(text),
    _ => null,
  };

  static String? _textValue(dynamic value) => switch (value) {
    final String text => text,
    final num number => number.toString(),
    _ => null,
  };

  static List<String> _badgeTextValues(dynamic value) {
    if (value is! List) return const [];
    final result = <String>[];
    for (final badge in value) {
      final text = badge is Map
          ? _textValue(
              badge['text'] ??
                  badge['title'] ??
                  badge['name'] ??
                  badge['content'] ??
                  badge['label'],
            )
          : _textValue(badge);
      if (text != null && text.trim().isNotEmpty) result.add(text.trim());
    }
    return result;
  }

  SearchPgcItemModel.fromJson(Map<String, dynamic> json) {
    type = json['type'];
    mediaId = _intValue(json['media_id']);
    title = Em.regTitle(json['title']);
    orgTitle = _textValue(json['org_title'] ?? json['original_title']);
    mediaType = _intValue(json['media_type']);
    cv = _textValue(json['cv']);
    staff = _textValue(json['staff']);
    seasonId = _intValue(json['season_id']);
    isAvid = json['is_avid'];
    hitEpids = json['hit_epids'];
    seasonType = _intValue(json['season_type']);
    seasonTypeName = _textValue(json['season_type_name']);
    url = _textValue(json['url']);
    buttonText = _textValue(json['button_text']);
    isFollow = _intValue(json['is_follow']);
    isSelection = _intValue(json['is_selection']);
    cover = _textValue(json['cover']);
    areas = _textValue(json['areas'] ?? json['area']);
    styles = _textValue(json['styles'] ?? json['style'] ?? json['styles_v2']);
    gotoUrl = _textValue(json['goto_url'] ?? json['goto'] ?? json['uri']);
    desc = _textValue(json['desc'] ?? json['description'] ?? json['prompt']);
    pubtime = _intValue(json['pubtime']);
    fixPubtimeStr = json['fix_pubtime_str']?.toString();
    mediaMode = _intValue(json['media_mode']);
    final score = json['media_score'];
    mediaScore = score is Map
        ? score
        : _intValue(json['rating']) != null
        ? {'score': json['rating'], 'user_count': json['vote']}
        : null;
    indexShow = _textValue(json['index_show'] ?? json['play_state']);
    final episodes = json['episodes'] ?? json['eps'];
    episodeCount =
        _intValue(json['ep_size'] ?? json['num_episodes']) ??
        (episodes is List ? episodes.length : null);
    allNetName = _textValue(json['all_net_name'] ?? json['out_name']);
    final styleLabel = json['style_label'];
    label =
        _textValue(json['label'] ?? json['angle_title']) ??
        (styleLabel is Map
            ? _textValue(
                styleLabel['text'] ?? styleLabel['title'] ?? styleLabel['name'],
              )
            : null);
    badgeTexts = [
      ..._badgeTextValues(json['badges']),
      ..._badgeTextValues(json['badges_v2']),
      ..._badgeTextValues(json['display_info']),
    ].toSet().toList(growable: false);
    isResolverInjected =
        json['resolver_injected'] == true ||
        json['is_resolver_injected'] == true ||
        json['resolver_injection_source'] == 'Bilibili-Region-Proxy';
  }
}

class SearchArticleData extends SearchNumData<SearchArticleItemModel> {
  SearchArticleData({super.numResults, super.list});

  SearchArticleData.fromJson(Map<String, dynamic> json) {
    numResults = (json['numResults'] as num?)?.toInt();
    list = (json['result'] as List?)
        ?.whereNotBlocked((e) => e['mid'])
        .map((e) => SearchArticleItemModel.fromJson(e))
        .toList();
  }
}

class SearchArticleItemModel {
  SearchArticleItemModel({
    this.pubTime,
    this.like,
    required this.title,
    this.subTitle,
    this.rankOffset,
    this.mid,
    this.imageUrls,
    this.id,
    this.categoryId,
    this.view,
    this.reply,
    this.desc,
    this.rankScore,
    this.type,
    this.templateId,
    this.categoryName,
  });

  int? pubTime;
  int? like;
  late List<({bool isEm, String text})> title;
  String? subTitle;
  int? rankOffset;
  int? mid;
  List<String>? imageUrls;
  int? id;
  int? categoryId;
  int? view;
  int? reply;
  String? desc;
  int? rankScore;
  String? type;
  int? templateId;
  String? categoryName;

  SearchArticleItemModel.fromJson(Map<String, dynamic> json) {
    pubTime = json['pub_time'];
    like = json['like'];
    title = Em.regTitle(json['title']);
    subTitle = title.map((e) => e.text).join();
    rankOffset = json['rank_offset'];
    mid = json['mid'];
    imageUrls = (json['image_urls'] as List?)?.fromCast();
    id = json['id'];
    categoryId = json['category_id'];
    view = json['view'];
    reply = json['reply'];
    desc = json['desc'];
    rankScore = json['rank_score'];
    type = json['type'];
    templateId = json['templateId'];
    categoryName = json['category_name'];
  }
}
