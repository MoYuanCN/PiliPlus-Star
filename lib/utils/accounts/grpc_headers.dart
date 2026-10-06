import 'dart:convert';

import 'package:PiliPlus/common/constants.dart';
import 'package:PiliPlus/grpc/bilibili/metadata.pb.dart';
import 'package:PiliPlus/grpc/bilibili/metadata/device.pb.dart';
import 'package:PiliPlus/grpc/bilibili/metadata/fawkes.pb.dart';
import 'package:PiliPlus/grpc/bilibili/metadata/locale.pb.dart';
import 'package:PiliPlus/grpc/bilibili/metadata/network.pb.dart' as network;
import 'package:PiliPlus/grpc/bilibili/metadata/restriction.pb.dart';
import 'package:PiliPlus/utils/login_utils.dart';
import 'package:PiliPlus/utils/utils.dart';

abstract final class GrpcHeaders {
  static const _build = 2001100;
  static const _versionName = '2.0.1';
  static const _biliChannel = 'master';
  static const _mobiApp = 'android_hd';
  static const _device = 'android';

  // Fixed app identity observed in the international Android app's
  // SearchByType request. Authentication and user identity remain dynamic.
  static const _intlAppId = 14;
  static const _intlBuild = 9130300;
  static const _intlVersionName = '6.6.0';
  static const _intlMobiApp = 'android_i';
  static const _intlChannel = 'pink_overseas';

  static String get _buvid => LoginUtils.buvid;
  static String get _traceId => Constants.traceId;
  static String get _sessionId => Utils.generateRandomString(8);

  static final Map<String, String> _base = {
    'grpc-encoding': 'gzip',
    'gzip-accept-encoding': 'gzip,identity',
    'user-agent': Constants.userAgent,
    'x-bili-gaia-vtoken': '',
    'x-bili-aurora-zone': '',
    'x-bili-trace-id': _traceId,
    'buvid': _buvid,
    'bili-http-engine': 'cronet',
    // 'te': 'trailers', // dio not supported
    'x-bili-device-bin': base64Encode(
      Device(
        appId: 5,
        build: _build,
        buvid: _buvid,
        mobiApp: _mobiApp,
        platform: _device,
        channel: _biliChannel,
        brand: _device,
        model: _device,
        osver: '15',
        versionName: _versionName,
      ).writeToBuffer(),
    ),
    'x-bili-network-bin': base64Encode(
      network.Network(type: network.NetworkType.WIFI).writeToBuffer(),
    ),
    'x-bili-locale-bin': base64Encode(
      Locale(
        cLocale: LocaleIds(language: 'zh', region: 'CN', script: 'Hans'),
        sLocale: LocaleIds(language: 'zh', region: 'CN', script: 'Hans'),
        timezone: 'Asia/Shanghai',
      ).writeToBuffer(),
    ),
    'x-bili-exps-bin': '',
  };

  static String get fawkes => base64Encode(
    FawkesReq(
      appkey: _mobiApp,
      env: 'prod',
      sessionId: _sessionId,
    ).writeToBuffer(),
  );

  static Map<String, String> newHeaders([String? accessKey]) {
    return {
      ..._base,
      if (accessKey != null) 'authorization': 'identify_v1 $accessKey',
      'x-bili-fawkes-req-bin': fawkes,
      'x-bili-metadata-bin': base64Encode(
        Metadata(
          accessKey: accessKey,
          mobiApp: _mobiApp,
          device: _device,
          build: _build,
          channel: _biliChannel,
          buvid: _buvid,
          platform: _device,
        ).writeToBuffer(),
      ),
    };
  }

  static Map<String, String> newIntlSearchHeaders({
    required String? accessKey,
    required int mid,
    required String buvid,
    String? auroraEid,
  }) {
    const device = 'android';
    final localeIds = LocaleIds(
      language: 'zh',
      script: 'Hans',
      region: 'SG',
    );
    final deviceMetadata = Device(
      appId: _intlAppId,
      build: _intlBuild,
      buvid: buvid,
      mobiApp: _intlMobiApp,
      platform: device,
      channel: _intlChannel,
      osver: '15',
      versionName: _intlVersionName,
    );
    final appMetadata = Metadata(
      accessKey: accessKey,
      mobiApp: _intlMobiApp,
      device: device,
      build: _intlBuild,
      channel: _intlChannel,
      buvid: buvid,
      platform: device,
    );
    final localeMetadata = Locale(
      cLocale: localeIds,
      sLocale: localeIds,
      timezone: 'Asia/Bangkok',
    );
    return {
      'user-agent':
          'Mozilla/5.0 BiliDroid/$_intlVersionName os/android model/android '
          'mobi_app/$_intlMobiApp build/$_intlBuild channel/$_intlChannel '
          'innerVer/$_intlBuild osVer/15 network/2',
      'grpc-accept-encoding': 'gzip,identity',
      'x-bili-gaia-vtoken': '',
      'x-bili-aurora-zone': '',
      'x-bili-trace-id': _traceId,
      'buvid': buvid,
      'bili-http-engine': 'cronet',
      'x-bili-device-bin': base64Encode(deviceMetadata.writeToBuffer()),
      'x-bili-network-bin': base64Encode(
        network.Network(type: network.NetworkType.WIFI).writeToBuffer(),
      ),
      'x-bili-locale-bin': base64Encode(localeMetadata.writeToBuffer()),
      'x-bili-fawkes-req-bin': base64Encode(
        FawkesReq(
          appkey: _intlMobiApp,
          env: 'prod',
          sessionId: _sessionId,
        ).writeToBuffer(),
      ),
      'x-bili-metadata-bin': base64Encode(appMetadata.writeToBuffer()),
      'x-bili-restriction-bin': base64Encode(
        Restriction().writeToBuffer(),
      ),
      'x-bili-exps-bin': '',
      'x-bili-mid': '$mid',
      if (auroraEid?.isNotEmpty == true) 'x-bili-aurora-eid': auroraEid!,
      if (accessKey?.isNotEmpty == true)
        'authorization': 'identify_v1 $accessKey',
      'x-bili-metadata-ip-region': 'TH',
      'x-bili-metadata-legal-region': 'TH',
    };
  }
}
