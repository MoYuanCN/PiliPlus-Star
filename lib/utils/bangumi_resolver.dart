import 'dart:io';

import 'package:PiliPlus/http/init.dart';
import 'package:PiliPlus/models/common/account_type.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:dio/dio.dart';

enum BangumiRegion {
  cn('中国大陆', 'CN', SettingBoxKey.bangumiResolverCn, SettingBoxKey.bangumiCdnCn),
  hk('港澳', 'HK', SettingBoxKey.bangumiResolverHk, SettingBoxKey.bangumiCdnHk),
  tw('台湾', 'TW', SettingBoxKey.bangumiResolverTw, SettingBoxKey.bangumiCdnTw),
  sea(
    '东南亚',
    'TH',
    SettingBoxKey.bangumiResolverSea,
    SettingBoxKey.bangumiCdnSea,
  );

  const BangumiRegion(this.label, this.mode, this.resolverKey, this.cdnKey);
  final String label;
  final String mode;
  final String resolverKey;
  final String cdnKey;

  String get resolver =>
      (GStorage.setting.get(resolverKey, defaultValue: '') as String).trim();
  String get cdn =>
      (GStorage.setting.get(cdnKey, defaultValue: '') as String).trim();

  static bool get enabled => GStorage.setting.get(
    SettingBoxKey.enableBangumiResolver,
    defaultValue: false,
  );

  static List<BangumiRegion> get configured => enabled
      ? values.where((region) => region.resolver.isNotEmpty).toList()
      : const [];

  static BangumiRegion? byMode(String? mode) {
    if (mode == null) return null;
    final normalized = mode.toUpperCase();
    return switch (normalized) {
      'CN' => cn,
      'HK' || 'MO' || 'HK/MO' => hk,
      'TW' => tw,
      'TH' || 'SEA' || 'INTL' => sea,
      _ => null,
    };
  }

  Uri endpoint(String path) {
    final base = Uri.parse(resolver.endsWith('/') ? resolver : '$resolver/');
    return base.resolve(path.replaceFirst(RegExp(r'^/'), ''));
  }
}

abstract final class BangumiResolverRequest {
  static Future<Response<dynamic>> get({
    required BangumiRegion region,
    required String path,
    Map<String, dynamic>? query,
    required AccountType accountType,
    bool includeResolverMode = false,
  }) async {
    final account = Accounts.get(accountType);
    final cookies = await account.cookieJar.loadForRequest(
      Uri.https('www.bilibili.com', '/'),
    );
    final cookieHeader = cookies
        .map((cookie) => '${cookie.name}=${cookie.value}')
        .join('; ');
    return Request().get(
      region.endpoint(path).toString(),
      queryParameters: query,
      options: Options(
        sendTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 20),
        extra: {'account': account},
        headers: {
          ...account.headers,
          if (cookieHeader.isNotEmpty) HttpHeaders.cookieHeader: cookieHeader,
          if (includeResolverMode) 'resolver_mode': region.mode,
        },
      ),
    );
  }
}
