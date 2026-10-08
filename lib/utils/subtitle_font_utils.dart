import 'dart:io';

import 'package:PiliPlus/utils/path_utils.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;

abstract final class SubtitleFontUtils {
  static const extensions = ['ttf', 'otf', 'ttc'];
  static const directoryName = 'subtitle_fonts';

  static Directory get directory =>
      Directory(path.join(appSupportDirPath, directoryName));

  static String? _fontExtension(String name) {
    final extension = path.extension(name);
    if (extension.length < 2) return null;
    final value = extension.substring(1).toLowerCase();
    return extensions.contains(value) ? value : null;
  }

  static Future<Directory> ensureDirectory() =>
      directory.create(recursive: true);

  static Future<List<File>> listFonts() async {
    final dir = await ensureDirectory();
    final files = await dir
        .list()
        .where((entity) => entity is File)
        .cast<File>()
        .where((file) => _fontExtension(file.path) != null)
        .toList();
    files.sort(
      (a, b) => path.basename(a.path).compareTo(path.basename(b.path)),
    );
    return files;
  }

  static Future<List<File>> importFonts() async {
    final selected = await FilePicker.pickFiles(
      type: .custom,
      allowedExtensions: extensions,
    );
    if (selected.isEmpty) return const [];

    final dir = await ensureDirectory();
    final imported = <File>[];
    for (final item in selected) {
      final extension = _fontExtension(item.name);
      if (extension == null) continue;
      final bytes = await item.readAsBytes();
      if (bytes.isEmpty) continue;

      final baseName = path.basename(item.name);
      var target = File(path.join(dir.path, baseName));
      var suffix = 1;
      while (target.existsSync()) {
        target = File(
          path.join(
            dir.path,
            '${path.basenameWithoutExtension(baseName)}-$suffix.$extension',
          ),
        );
        suffix++;
      }
      await target.writeAsBytes(bytes, flush: true);
      imported.add(target);
    }
    return imported;
  }

  static Future<void> deleteFont(File file) async {
    final normalizedDirectory = path.normalize(directory.absolute.path);
    final normalizedFile = path.normalize(file.absolute.path);
    final fileDirectory = path.dirname(normalizedFile);
    final sameDirectory = Platform.isWindows
        ? fileDirectory.toLowerCase() == normalizedDirectory.toLowerCase()
        : fileDirectory == normalizedDirectory;
    if (!sameDirectory) {
      throw ArgumentError.value(file.path, 'file', '字体文件必须位于字幕字体目录中');
    }
    if (file.existsSync()) await file.delete();
  }
}
