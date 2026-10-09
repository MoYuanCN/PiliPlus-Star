import 'dart:io';

import 'package:PiliPlus/utils/path_utils.dart';
import 'package:path/path.dart' as path;

abstract final class MpvConfig {
  static const directoryName = 'mpv';
  static const mpvFileName = 'mpv.conf';
  static const inputFileName = 'input.conf';

  static String get directoryPath =>
      path.join(appSupportDirPath, directoryName);
  static String get mpvFilePath => path.join(directoryPath, mpvFileName);
  static String get inputFilePath => path.join(directoryPath, inputFileName);

  static Future<Directory> ensureDirectory() =>
      Directory(directoryPath).create(recursive: true);

  static Future<Map<String, String>> playerOptions({
    required bool enabled,
  }) async {
    if (!enabled) return const {};
    await ensureDirectory();
    final options = <String, String>{
      'config': 'yes',
      'config-dir': directoryPath,
    };
    return options;
  }
}
