import 'dart:io';

import 'package:PiliPlus/http/init.dart';
import 'package:PiliPlus/models/common/account_type.dart';
import 'package:PiliPlus/models/common/video/cdn_type.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/accounts/account.dart';
import 'package:PiliPlus/utils/accounts/grpc_headers.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:dio/dio.dart';

enum BangumiRegion {
  cn(
    '中国大陆',
    'CN',
    SettingBoxKey.bangumiResolverCn,
    SettingBoxKey.bangumiCdnCn,
    SettingBoxKey.bangumiResolverModeCn,
  ),
  hk(
    '港澳',
    'HK',
    SettingBoxKey.bangumiResolverHk,
    SettingBoxKey.bangumiCdnHk,
    SettingBoxKey.bangumiResolverModeHk,
  ),
  tw(
    '台湾',
    'TW',
    SettingBoxKey.bangumiResolverTw,
    SettingBoxKey.bangumiCdnTw,
    SettingBoxKey.bangumiResolverModeTw,
  ),
  sea(
    '东南亚',
    'INTL',
    SettingBoxKey.bangumiResolverSea,
    SettingBoxKey.bangumiCdnSea,
    SettingBoxKey.bangumiResolverModeSea,
  );

  const BangumiRegion(
    this.label,
    this.mode,
    this.resolverKey,
    this.cdnKey,
    this.resolverModeKey,
  );
  final String label;
  final String mode;
  final String resolverKey;
  final String cdnKey;
  final String resolverModeKey;

  String get resolver =>
      (GStorage.setting.get(resolverKey, defaultValue: '') as String).trim();
  String get resolverMode {
    final value = GStorage.setting.get(resolverModeKey, defaultValue: mode);
    if (value is! String || value.trim().isEmpty) return mode;
    final configuredMode = value.trim();
    if (this == BangumiRegion.sea && configuredMode.toUpperCase() == 'TH') {
      return 'INTL';
    }
    return configuredMode;
  }

  String get cdn =>
      (GStorage.setting.get(cdnKey, defaultValue: '') as String).trim();

  CDNService? get cdnService {
    final value = cdn;
    if (value.isEmpty) return null;
    for (final service in CDNService.values) {
      if (service.name == value || service.host == value) return service;
    }
    final uri = Uri.tryParse(value.contains('://') ? value : 'https://$value');
    if (uri != null) {
      for (final service in CDNService.values) {
        if (service.host == uri.host) return service;
      }
    }
    return null;
  }

  String? get legacyCdnHost =>
      cdn.isNotEmpty && cdnService == null ? cdn : null;

  static bool get enabled => GStorage.setting.get(
    SettingBoxKey.enableBangumiResolver,
    defaultValue: false,
  );

  static BangumiRegion? get defaultRegion => byMode(
    GStorage.setting.get(
      SettingBoxKey.bangumiResolverDefaultRegion,
      defaultValue: '',
    ) as String?,
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

  static List<BangumiRegion> candidates(String? preferredMode) {
    final preferred = byMode(preferredMode) ?? defaultRegion;
    return [
      if (preferred != null && configured.contains(preferred)) preferred,
      ...configured.where((region) => region != preferred),
    ];
  }

  static Future<void> setDefaultRegion(BangumiRegion? region) => GStorage
      .setting
      .put(SettingBoxKey.bangumiResolverDefaultRegion, region?.mode ?? '');

  static String normalizeResolverAddress(String address) {
    final value = address.trim();
    if (value.isEmpty) return '';
    final hasHttpScheme = RegExp(r'^https?://', caseSensitive: false).hasMatch(
      value,
    );
    final uri = Uri.tryParse(hasHttpScheme ? value : 'https://$value');
    if (uri == null ||
        !{'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException('请输入有效的 HTTP(S) 服务器地址。');
    }
    final path = uri.path.replaceFirst(RegExp(r'/+$'), '');
    final scheme = hasHttpScheme
        ? uri.scheme.toLowerCase()
        : (uri.hasPort && uri.port != 443) || _isLocalResolverHost(uri.host)
        ? 'http'
        : 'https';
    return uri.replace(scheme: scheme, path: path).toString();
  }

  static bool _isLocalResolverHost(String host) {
    final value = host.toLowerCase();
    if (value == 'localhost' ||
        value.endsWith('.localhost') ||
        value.endsWith('.local')) {
      return true;
    }
    final address = InternetAddress.tryParse(value);
    if (address == null) return false;
    final bytes = address.rawAddress;
    if (bytes.length == 4) {
      final first = bytes[0];
      final second = bytes[1];
      return first == 10 ||
          first == 127 ||
          (first == 169 && second == 254) ||
          (first == 172 && second >= 16 && second <= 31) ||
          (first == 192 && second == 168);
    }
    if (bytes.length == 16) {
      return address.isLoopback ||
          (bytes[0] == 0xfe && (bytes[1] & 0xc0) == 0x80) ||
          (bytes[0] & 0xfe) == 0xfc;
    }
    return false;
  }

  Uri get _resolverBaseUri {
    final address = normalizeResolverAddress(resolver);
    final uri = Uri.parse(address);
    final path = uri.path.endsWith('/') ? uri.path : '${uri.path}/';
    return uri.replace(path: path);
  }

  Uri endpoint(String path) {
    return _resolverBaseUri.resolve(path.replaceFirst(RegExp(r'^/'), ''));
  }
}

abstract final class BangumiResolverRequest {
  static Future<Response<dynamic>> get({
    required BangumiRegion region,
    required String path,
    Map<String, dynamic>? query,
    required AccountType accountType,
    bool includeResolverMode = false,
    bool useAccountCredentials = true,
    bool useIntlAppSearchMetadata = false,
    bool suppressResolverErrors = false,
    CancelToken? cancelToken,
    Duration receiveTimeout = const Duration(seconds: 20),
  }) async {
    final useIntlSearchCredentials =
        useAccountCredentials && useIntlAppSearchMetadata;
    var account = useAccountCredentials
        ? Accounts.get(accountType)
        : const NoAccount();
    final cookies = useAccountCredentials
        ? await account.cookieJar.loadForRequest(
            Uri.https('www.bilibili.com', '/'),
          )
        : const <Cookie>[];
    final cookieHeader = cookies
        .map((cookie) => '${cookie.name}=${cookie.value}')
        .join('; ');
    var buvid = '';
    if (useIntlSearchCredentials && account is! NoAccount) {
      buvid = account.grpcHeaders['buvid'] ?? '';
    }
    for (final cookie in cookies) {
      if (cookie.name == 'buvid3') {
        buvid = cookie.value;
        break;
      }
    }
    final requestHeaders = useIntlSearchCredentials
        ? GrpcHeaders.newIntlSearchHeaders(
            accessKey: account.accessKey,
            mid: account.isLogin ? account.mid : 0,
            buvid: buvid,
            auroraEid: account.headers['x-bili-aurora-eid'],
          )
        : const <String, String>{};
    return Request().get(
      region.endpoint(path).toString(),
      queryParameters: query,
      options: Options(
        sendTimeout: const Duration(seconds: 12),
        receiveTimeout: receiveTimeout,
        extra: {
          'account': account,
          if (useIntlSearchCredentials) 'preserveAccountHeaders': true,
          if (suppressResolverErrors) 'suppressResolverErrors': true,
        },
        headers: {
          if (useAccountCredentials && !useIntlSearchCredentials)
            ...account.headers,
          ...requestHeaders,
          if (cookieHeader.isNotEmpty) HttpHeaders.cookieHeader: cookieHeader,
          if (includeResolverMode) 'resolver_mode': region.resolverMode,
        },
      ),
      cancelToken: cancelToken,
    );
  }
}
