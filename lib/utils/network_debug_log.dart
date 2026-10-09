import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

const _networkDebugEntryExtraKey = '_piliNetworkDebugEntryId';

class NetworkDebugEntry {
  const NetworkDebugEntry({
    required this.id,
    required this.startedAt,
    this.kind = 'HTTP',
    required this.method,
    required this.url,
    required this.requestHeaders,
    required this.query,
    required this.requestBody,
    this.statusCode,
    this.responseHeaders = '',
    this.responseBody = '',
    this.durationMs,
    this.error = '',
  });

  final int id;
  final DateTime startedAt;
  final String kind;
  final String method;
  final String url;
  final String requestHeaders;
  final String query;
  final String requestBody;
  final int? statusCode;
  final String responseHeaders;
  final String responseBody;
  final int? durationMs;
  final String error;

  bool get isComplete =>
      kind != 'HTTP' || statusCode != null || error.isNotEmpty;

  NetworkDebugEntry copyWith({
    int? statusCode,
    String? responseHeaders,
    String? responseBody,
    int? durationMs,
    String? error,
  }) => NetworkDebugEntry(
    id: id,
    startedAt: startedAt,
    kind: kind,
    method: method,
    url: url,
    requestHeaders: requestHeaders,
    query: query,
    requestBody: requestBody,
    statusCode: statusCode ?? this.statusCode,
    responseHeaders: responseHeaders ?? this.responseHeaders,
    responseBody: responseBody ?? this.responseBody,
    durationMs: durationMs ?? this.durationMs,
    error: error ?? this.error,
  );
}

abstract final class NetworkDebugLog {
  static const maxEntries = 150;
  static const maxPreviewLength = 18000;

  static final ValueNotifier<List<NetworkDebugEntry>> entries = ValueNotifier(
    const [],
  );
  static int _nextId = 0;

  static int begin(RequestOptions options) {
    final id = ++_nextId;
    options.extra[_networkDebugEntryExtraKey] = id;
    final uri = options.uri.replace(query: '', fragment: '').toString();
    final query = options.queryParameters.isEmpty
        ? options.uri.queryParameters
        : options.queryParameters;
    final entry = NetworkDebugEntry(
      id: id,
      startedAt: DateTime.now(),
      method: options.method,
      url: uri,
      requestHeaders: _formatHeaders(options.headers),
      query: _formatValue(query),
      requestBody: _formatBody(options.data),
    );
    entries.value = [entry, ...entries.value].take(maxEntries).toList();
    return id;
  }

  static void appendPlayerEvent({
    required String level,
    required String prefix,
    required String message,
  }) {
    final entry = NetworkDebugEntry(
      id: ++_nextId,
      startedAt: DateTime.now(),
      kind: '播放器',
      method: level.toUpperCase(),
      url: prefix.isEmpty ? 'media_kit' : 'media_kit · $prefix',
      requestHeaders: '',
      query: '',
      requestBody: '',
      responseBody: _limit(_sanitizeText(message)),
    );
    entries.value = [entry, ...entries.value].take(maxEntries).toList();
  }

  static void complete(
    RequestOptions options, {
    required int? statusCode,
    required Map<String, List<String>> headers,
    required Object? data,
    String error = '',
  }) {
    final id = options.extra[_networkDebugEntryExtraKey];
    if (id is! int) return;
    final index = entries.value.indexWhere((entry) => entry.id == id);
    if (index == -1) return;
    final entry = entries.value[index].copyWith(
      statusCode: statusCode,
      responseHeaders: _formatHeaders(headers),
      responseBody: _formatBody(data),
      durationMs: DateTime.now()
          .difference(entries.value[index].startedAt)
          .inMilliseconds,
      error: error.isEmpty ? null : _limit(_sanitizeText(error)),
    );
    final updated = List<NetworkDebugEntry>.of(entries.value);
    updated[index] = entry;
    entries.value = updated;
  }

  static void clear() => entries.value = const [];

  static String _formatBody(Object? value) {
    if (value == null) return '(empty)';
    if (value is List<int>) return '[binary body: ${value.length} bytes]';
    if (value is ResponseBody) return '[stream response]';
    if (value is FormData) {
      return _formatValue({
        'fields': {
          for (final field in value.fields) field.key: field.value,
        },
        'files': [
          for (final file in value.files)
            {
              'field': file.key,
              'fileName': file.value.filename,
              'length': file.value.length,
            },
        ],
      });
    }
    if (value is String) {
      final text = value.trim();
      if (text.startsWith('{') || text.startsWith('[')) {
        try {
          return _formatValue(jsonDecode(text));
        } catch (_) {}
      }
      return _limit(_sanitizeText(value));
    }
    return _formatValue(value);
  }

  static String _formatHeaders(Map<dynamic, dynamic> headers) {
    final sanitized = <String, Object?>{};
    for (final entry in headers.entries) {
      final key = entry.key.toString();
      if (_isSensitiveKey(key)) {
        sanitized[key] = _redactedHeader(key, entry.value);
      } else {
        sanitized[key] = entry.value;
      }
    }
    return _formatValue(sanitized);
  }

  static String _formatValue(Object? value) {
    try {
      return _limit(jsonEncode(_sanitizeValue(value)));
    } catch (_) {
      return _limit(_sanitizeText(value.toString()));
    }
  }

  static Object? _sanitizeValue(Object? value, {String? key, int depth = 0}) {
    if (key != null && _isSensitiveKey(key)) return '[redacted]';
    if (depth > 8) return '[nested data omitted]';
    if (value == null || value is num || value is bool) return value;
    if (value is String) return _sanitizeText(value);
    if (value is List<int>) return '[binary: ${value.length} bytes]';
    if (value is Map) {
      final result = <String, Object?>{};
      var count = 0;
      for (final entry in value.entries) {
        if (count++ >= 100) {
          result['…'] = '[remaining fields omitted]';
          break;
        }
        final name = entry.key.toString();
        result[name] = _sanitizeValue(
          entry.value,
          key: name,
          depth: depth + 1,
        );
      }
      return result;
    }
    if (value is Iterable) {
      final result = <Object?>[];
      var count = 0;
      for (final item in value) {
        if (count++ >= 40) {
          result.add('[remaining items omitted]');
          break;
        }
        result.add(_sanitizeValue(item, depth: depth + 1));
      }
      return result;
    }
    return _sanitizeText(value.toString());
  }

  static String _sanitizeText(String value) {
    value = value.replaceAllMapped(
      RegExp(r'https?://[^\s"<>]+', caseSensitive: false),
      (match) {
        final uri = Uri.tryParse(match[0]!);
        if (uri == null || uri.queryParameters.isEmpty) return match[0]!;
        return uri
            .replace(
              queryParameters: {
                for (final entry in uri.queryParameters.entries)
                  entry.key: _isSensitiveKey(entry.key)
                      ? '[redacted]'
                      : entry.value,
              },
            )
            .toString();
      },
    );
    final uri = Uri.tryParse(value);
    if (uri != null &&
        const {'http', 'https'}.contains(uri.scheme.toLowerCase()) &&
        uri.host.isNotEmpty &&
        uri.hasQuery) {
      final query = <String, String>{};
      for (final entry in uri.queryParameters.entries) {
        query[entry.key] = _isSensitiveKey(entry.key)
            ? '[redacted]'
            : entry.value;
      }
      return uri.replace(queryParameters: query).toString();
    }
    return value
        .replaceAllMapped(
          RegExp(
            r'(access_key|accesskey|sessdata|bili_jct|csrf|refresh_token|access_token|authorization|cookie|sign|w_rid|buvid3?|device_id|auth_key|token|deadline|expires|wsSecret|wsTime|hdnts|mid)=([^&\s,]+)',
            caseSensitive: false,
          ),
          (match) => '${match[1]}=[redacted]',
        )
        .replaceAllMapped(
          RegExp(r'(Bearer\s+)[A-Za-z0-9._~+/-]+=*', caseSensitive: false),
          (match) => '${match[1]}[redacted]',
        );
  }

  static bool _isSensitiveKey(String key) {
    final normalized = key.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (const {
      'authorization',
      'cookie',
      'setcookie',
      'accesskey',
      'accesstoken',
      'refreshtoken',
      'sessdata',
      'bilijct',
      'csrf',
      'sign',
      'wrid',
      'buvid',
      'buvid3',
      'deviceid',
      'authkey',
      'token',
      'deadline',
      'expires',
      'wssecret',
      'wstime',
      'hdnts',
      'password',
      'secret',
      'mid',
    }.contains(normalized)) {
      return true;
    }
    return normalized.endsWith('authorization') ||
        normalized.endsWith('accesskey') ||
        normalized.endsWith('accesstoken') ||
        normalized.endsWith('refreshtoken') ||
        normalized.endsWith('sessdata') ||
        normalized.endsWith('bilijct') ||
        normalized.endsWith('buvid') ||
        normalized.endsWith('deviceid') ||
        normalized.endsWith('authkey') ||
        normalized.endsWith('wrid') ||
        normalized.endsWith('mid');
  }

  static Object? _redactedHeader(String key, Object? value) {
    if (key.toLowerCase() != 'cookie' && key.toLowerCase() != 'set-cookie') {
      return '[redacted]';
    }
    return value
        .toString()
        .split(';')
        .map((part) {
          final separator = part.indexOf('=');
          if (separator <= 0) return '[redacted]';
          final name = part.substring(0, separator).trim();
          return '$name=[redacted]';
        })
        .join('; ');
  }

  static String _limit(String text) {
    if (text.length <= maxPreviewLength) return text;
    return '${text.substring(0, maxPreviewLength)}\n… [truncated]';
  }
}

class NetworkDebugInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    NetworkDebugLog.begin(options);
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    NetworkDebugLog.complete(
      response.requestOptions,
      statusCode: response.statusCode,
      headers: response.headers.map,
      data: response.data,
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    NetworkDebugLog.complete(
      err.requestOptions,
      statusCode: err.response?.statusCode,
      headers: err.response?.headers.map ?? const {},
      data: err.response?.data,
      error: err.message ?? err.type.name,
    );
    handler.next(err);
  }
}
