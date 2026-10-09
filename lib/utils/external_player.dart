import 'dart:io';

import 'package:PiliPlus/http/browser_ua.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:path/path.dart' as path;

abstract final class ExternalPlayer {
  static Map<String, String>? _detectedPlayers;

  static Future<Map<String, String>> detectInstalledPlayers({
    bool refresh = false,
  }) async {
    if (!refresh && _detectedPlayers != null) return _detectedPlayers!;
    _detectedPlayers = {
      'mpv': _findExecutable('mpv', const ['mpv.exe', 'mpv']),
      'potplayer': Platform.isWindows
          ? _findExecutable('potplayer', const [
              'PotPlayerMini64.exe',
              'PotPlayerMini.exe',
              'PotPlayerMiniXP.exe',
            ])
          : '',
    };
    return _detectedPlayers!;
  }

  static Future<void> play({
    required String video,
    String? audio,
    String? subtitle,
    String? title,
  }) async {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      throw UnsupportedError('外部播放器启动目前支持 Windows、macOS 和 Linux');
    }

    final type = Pref.externalPlayerType == 'potplayer'
        ? 'potplayer'
        : Pref.externalPlayerType == 'custom'
        ? 'custom'
        : 'mpv';
    final configuredPath = switch (type) {
      'potplayer' => Pref.externalPlayerPotPlayerPath,
      'custom' => Pref.externalPlayerPath,
      _ => Pref.externalPlayerMpvPath,
    }.trim();
    final detected = await detectInstalledPlayers();
    final executable = configuredPath.isNotEmpty
        ? configuredPath
        : detected[type] ?? '';
    if (executable.isEmpty) {
      throw StateError(
        type == 'potplayer'
            ? '未找到 PotPlayer，请在设置中自动识别或填写程序路径'
            : '未找到 MPV，请在设置中自动识别或填写程序路径',
      );
    }
    if (!File(executable).existsSync()) {
      throw FileSystemException('找不到外部播放器程序', executable);
    }

    final configuredArguments = switch (type) {
      'potplayer' => Pref.externalPlayerPotPlayerArguments,
      'custom' => Pref.externalPlayerArguments,
      _ => Pref.externalPlayerMpvArguments,
    };
    final template = configuredArguments.trim().isNotEmpty
        ? configuredArguments
        : _defaultArguments(type);
    final values = <String, String>{
      'video': video,
      'audio': audio ?? '',
      'subtitle': subtitle ?? '',
      'title': title ?? '',
      'referer': 'https://www.bilibili.com/',
      'userAgent': BrowserUa.pc,
    };
    final args = <String>[];
    final placeholders = RegExp(
      r'\{(video|audio|subtitle|title|referer|userAgent)\}',
    );
    for (final token in _tokenize(template)) {
      final matches = placeholders.allMatches(token);
      if (matches.any((match) => values[match.group(1)]!.isEmpty)) continue;
      var value = token;
      for (final entry in values.entries) {
        value = value.replaceAll('{${entry.key}}', entry.value);
      }
      if (value.isNotEmpty && !value.contains('{')) args.add(value);
    }

    if (!template.contains('{video}')) args.insert(0, video);
    await Process.start(executable, args, mode: ProcessStartMode.detached);
  }

  static String _defaultArguments(String type) => switch (type) {
    'potplayer' => '"{video}" /play /sub="{subtitle}" /audiofile="{audio}"',
    'custom' => '"{video}"',
    _ => '"{video}" --audio-file="{audio}" --sub-file="{subtitle}" --force-media-title="{title}" --referrer="{referer}" --user-agent="{userAgent}"',
  };

  static String _findExecutable(String type, List<String> executableNames) {
    final candidates = <String>[];
    for (final executableName in executableNames) {
      candidates.addAll(_fromPath(executableName));
    }

    if (Platform.isWindows) {
      final programFiles =
          Platform.environment['ProgramFiles'] ?? r'C:\Program Files';
      final programFilesX86 =
          Platform.environment['ProgramFiles(x86)'] ??
          r'C:\Program Files (x86)';
      final localAppData = Platform.environment['LOCALAPPDATA'] ?? '';
      final userProfile = Platform.environment['USERPROFILE'] ?? '';
      if (type == 'mpv') {
        candidates.addAll([
          path.join(programFiles, 'mpv', 'mpv.exe'),
          path.join(programFiles, 'mpv', 'bin', 'mpv.exe'),
          path.join(programFilesX86, 'mpv', 'mpv.exe'),
          if (localAppData.isNotEmpty)
            path.join(localAppData, 'Programs', 'mpv', 'mpv.exe'),
          if (userProfile.isNotEmpty)
            path.join(
              userProfile,
              'scoop',
              'apps',
              'mpv',
              'current',
              'mpv.exe',
            ),
        ]);
      } else {
        candidates.addAll([
          for (final root in [programFiles, programFilesX86]) ...[
            path.join(root, 'DAUM', 'PotPlayer', 'PotPlayerMini64.exe'),
            path.join(root, 'DAUM', 'PotPlayer', 'PotPlayerMini.exe'),
            path.join(root, 'PotPlayer', 'PotPlayerMini64.exe'),
            path.join(root, 'PotPlayer', 'PotPlayerMini.exe'),
          ],
          if (localAppData.isNotEmpty)
            path.join(
              localAppData,
              'Programs',
              'PotPlayer',
              'PotPlayerMini64.exe',
            ),
        ]);
      }
      candidates.addAll(_fromRegistry(type, executableNames));
    }

    final seen = <String>{};
    for (final candidate in candidates) {
      final value = candidate.trim().replaceAll('"', '');
      if (value.isEmpty) continue;
      final key = Platform.isWindows ? value.toLowerCase() : value;
      if (seen.add(key) && File(value).existsSync()) return value;
    }
    return '';
  }

  static List<String> _fromPath(String executableName) {
    final result = <String>[];
    final searchPath = Platform.environment['PATH'] ?? '';
    final pathListSeparator = Platform.isWindows ? ';' : ':';
    for (final directory in searchPath.split(pathListSeparator)) {
      if (directory.trim().isEmpty) continue;
      result.add(path.join(directory.trim(), executableName));
    }

    final command = Platform.isWindows ? 'where.exe' : 'which';
    try {
      final process = Process.runSync(
        command,
        [executableName],
        runInShell: Platform.isWindows,
      );
      if (process.exitCode == 0) {
        result.addAll(
          process.stdout
              .toString()
              .split(RegExp(r'\r?\n'))
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty),
        );
      }
    } catch (_) {}
    return result;
  }

  static List<String> _fromRegistry(
    String type,
    List<String> executableNames,
  ) {
    if (!Platform.isWindows) return const [];
    final keys = <String>[
      for (final executableName in executableNames) ...[
        'HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\App Paths\\$executableName',
        'HKLM\\Software\\Microsoft\\Windows\\CurrentVersion\\App Paths\\$executableName',
        'HKLM\\Software\\WOW6432Node\\Microsoft\\Windows\\CurrentVersion\\App Paths\\$executableName',
      ],
      if (type == 'potplayer') ...[
        r'HKCU\Software\DAUM\PotPlayer64',
        r'HKCU\Software\DAUM\PotPlayer',
        r'HKLM\Software\DAUM\PotPlayer64',
        r'HKLM\Software\DAUM\PotPlayer',
        r'HKLM\Software\WOW6432Node\DAUM\PotPlayer64',
      ],
    ];
    final values = <String>[];
    for (final key in keys) {
      try {
        final process = Process.runSync('reg.exe', ['query', key]);
        if (process.exitCode != 0) continue;
        for (final line in process.stdout.toString().split(RegExp(r'\r?\n'))) {
          final match = RegExp(r'\s+REG_SZ\s+(.+)$').firstMatch(line);
          final value = match?.group(1)?.trim();
          if (value != null && value.isNotEmpty) values.add(value);
        }
      } catch (_) {}
    }
    final executables = <String>[];
    for (final value in values) {
      final location = value.trim().replaceAll('"', '');
      if (Directory(location).existsSync()) {
        executables.addAll(
          executableNames.map((name) => path.join(location, name)),
        );
      } else {
        executables.add(location);
      }
    }
    return executables;
  }

  static List<String> _tokenize(String value) {
    final tokens = <String>[];
    final pattern = RegExp(r'''"([^"]*)"|'([^']*)'|(\S+)''');
    for (final match in pattern.allMatches(value)) {
      tokens.add(match.group(1) ?? match.group(2) ?? match.group(3)!);
    }
    return tokens;
  }
}
