import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show loadFontFromList;

import 'package:PiliPlus/utils/path_utils.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as path;

enum SubtitleFontSource { bundled, app, system }

class SubtitleFontFace {
  const SubtitleFontFace({
    required this.family,
    required this.source,
    this.file,
  });

  final String family;
  final SubtitleFontSource source;
  final File? file;

  String get sourceLabel => switch (source) {
    .bundled => '应用内置字体',
    .app => '应用字体文件夹',
    .system => '系统字体',
  };
}

abstract final class SubtitleFontUtils {
  static const extensions = ['ttf', 'otf', 'ttc'];
  static const directoryName = 'subtitle_fonts';
  static const bundledAssetDirectory = 'assets/fonts/subtitles';
  static const bundledFontName = 'DreamHanSans-W22.ttc';
  static const bundledFontAsset = '$bundledAssetDirectory/$bundledFontName';
  static const defaultFontFamily = 'Dream Han Sans SC';

  static final Map<String, String> _previewFontFamilies = {};
  static final Map<String, ({int size, int modified, List<String> families})>
  _familyCache = {};

  static Directory get directory =>
      Directory(path.join(appSupportDirPath, directoryName));

  static String? _fontExtension(String name) {
    final extension = path.extension(name);
    if (extension.length < 2) return null;
    final value = extension.substring(1).toLowerCase();
    return extensions.contains(value) ? value : null;
  }

  static Future<Directory> ensureDirectory() async {
    final dir = await directory.create(recursive: true);
    final bundledFont = File(path.join(dir.path, bundledFontName));
    if (!await bundledFont.exists()) {
      final data = await rootBundle.load(bundledFontAsset);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      await bundledFont.writeAsBytes(bytes, flush: true);
    }
    return dir;
  }

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

  static Future<List<SubtitleFontFace>> discoverFonts({
    required Iterable<String> systemFamilies,
  }) async {
    final files = await listFonts();
    final faces = <SubtitleFontFace>[];
    for (final file in files) {
      final isBundled = path.basename(file.path) == bundledFontName;
      final families = await _readFontFamilies(file);
      for (final family in families) {
        faces.add(
          SubtitleFontFace(
            family: family,
            source: isBundled ? .bundled : .app,
            file: file,
          ),
        );
      }
    }

    for (final family in systemFamilies) {
      if (family.trim().isEmpty) continue;
      faces.add(
        SubtitleFontFace(family: family.trim(), source: .system),
      );
    }

    faces.sort((a, b) {
      final byFamily = a.family.toLowerCase().compareTo(b.family.toLowerCase());
      if (byFamily != 0) return byFamily;
      return a.source.index.compareTo(b.source.index);
    });
    return faces;
  }

  static List<String> systemFontDirectories() {
    final home = Platform.environment['HOME'] ?? '';
    final candidates = switch (Platform.operatingSystem) {
      'windows' => <String>[
        path.join(Platform.environment['WINDIR'] ?? r'C:\Windows', 'Fonts'),
        if (Platform.environment['LOCALAPPDATA'] case final localAppData?)
          path.join(localAppData, 'Microsoft', 'Windows', 'Fonts'),
      ],
      'android' => <String>[
        '/system/fonts',
        '/system_ext/fonts',
        '/product/fonts',
        '/vendor/fonts',
      ],
      'macos' || 'ios' => <String>[
        '/System/Library/Fonts',
        '/Library/Fonts',
        if (home.isNotEmpty) path.join(home, 'Library', 'Fonts'),
      ],
      _ => <String>[
        '/usr/share/fonts',
        '/usr/local/share/fonts',
        if (home.isNotEmpty) path.join(home, '.local', 'share', 'fonts'),
      ],
    };

    return candidates
        .where((directory) => Directory(directory).existsSync())
        .toList();
  }

  static Future<String> loadPreviewFamily(SubtitleFontFace face) async {
    final file = face.file;
    if (file == null) return face.family;

    final stat = await file.stat();
    final cacheKey =
        '${file.path}:${stat.size}:${stat.modified.microsecondsSinceEpoch}';
    final cachedFamily = _previewFontFamilies[cacheKey];
    if (cachedFamily != null) return cachedFamily;

    final family =
        'PiliPlusSubtitlePreview${cacheKey.hashCode.toRadixString(16)}';
    final bytes = await file.readAsBytes();
    await loadFontFromList(bytes, fontFamily: family);
    _previewFontFamilies[cacheKey] = family;
    return family;
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
      while (await target.exists()) {
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
    if (path.basename(file.path) == bundledFontName) {
      throw ArgumentError.value(file.path, 'file', '应用内置字体不可删除');
    }
    if (await file.exists()) await file.delete();
  }

  static Future<List<String>> _readFontFamilies(File file) async {
    RandomAccessFile? handle;
    try {
      final stat = await file.stat();
      final modified = stat.modified.microsecondsSinceEpoch;
      final cached = _familyCache[file.path];
      if (cached != null &&
          cached.size == stat.size &&
          cached.modified == modified) {
        return cached.families;
      }
      handle = await file.open();
      final length = await handle.length();
      final header = await _readAt(handle, 0, 12);
      if (header.length != 12) return const [];

      final isCollection = ascii.decode(header.take(4).toList()) == 'ttcf';
      final faceOffsets = <int>[];
      if (isCollection) {
        final fontCount = ByteData.sublistView(header).getUint32(8, Endian.big);
        if (fontCount == 0 || fontCount > 128) return const [];
        final offsets = await _readAt(handle, 12, fontCount * 4);
        if (offsets.length != fontCount * 4) return const [];
        final data = ByteData.sublistView(offsets);
        for (var i = 0; i < fontCount; i++) {
          faceOffsets.add(data.getUint32(i * 4, Endian.big));
        }
      } else {
        faceOffsets.add(0);
      }

      final families = <String>{};
      for (final faceOffset in faceOffsets) {
        if (faceOffset < 0 || faceOffset + 12 > length) continue;
        final faceHeader = await _readAt(handle, faceOffset, 12);
        if (faceHeader.length != 12) continue;
        final tableCount = ByteData.sublistView(faceHeader).getUint16(
          4,
          Endian.big,
        );
        if (tableCount == 0 || tableCount > 4096) continue;
        final tableDirectory = await _readAt(
          handle,
          faceOffset + 12,
          tableCount * 16,
        );
        if (tableDirectory.length != tableCount * 16) continue;
        final directoryData = ByteData.sublistView(tableDirectory);
        for (var i = 0; i < tableCount; i++) {
          final entryOffset = i * 16;
          final tag = ascii.decode(
            tableDirectory.sublist(entryOffset, entryOffset + 4),
            allowInvalid: true,
          );
          if (tag != 'name') continue;
          final tableOffset = directoryData.getUint32(
            entryOffset + 8,
            Endian.big,
          );
          final tableLength = directoryData.getUint32(
            entryOffset + 12,
            Endian.big,
          );
          if (tableLength < 6 || tableLength > 1024 * 1024) continue;
          if (tableOffset + tableLength > length) continue;
          final nameTable = await _readAt(handle, tableOffset, tableLength);
          final family = _familyFromNameTable(nameTable);
          if (family != null) families.add(family);
          break;
        }
      }
      final result = families.toList()..sort();
      _familyCache[file.path] = (
        size: stat.size,
        modified: modified,
        families: result,
      );
      return result;
    } catch (_) {
      return const [];
    } finally {
      await handle?.close();
    }
  }

  static Future<Uint8List> _readAt(
    RandomAccessFile handle,
    int offset,
    int count,
  ) async {
    await handle.setPosition(offset);
    return handle.read(count);
  }

  static String? _familyFromNameTable(Uint8List table) {
    final data = ByteData.sublistView(table);
    final count = data.getUint16(2, Endian.big);
    final stringsOffset = data.getUint16(4, Endian.big);
    if (6 + count * 12 > table.length) return null;

    final names = <int, List<(int, int, String)>>{16: [], 1: []};
    for (var i = 0; i < count; i++) {
      final offset = 6 + i * 12;
      final platformId = data.getUint16(offset, Endian.big);
      final languageId = data.getUint16(offset + 4, Endian.big);
      final nameId = data.getUint16(offset + 6, Endian.big);
      final byteLength = data.getUint16(offset + 8, Endian.big);
      final byteOffset = data.getUint16(offset + 10, Endian.big);
      if (!names.containsKey(nameId)) continue;
      final start = stringsOffset + byteOffset;
      final end = start + byteLength;
      if (start < stringsOffset || end > table.length) continue;
      final bytes = table.sublist(start, end);
      final name = platformId == 0 || platformId == 3
          ? _decodeUtf16Be(bytes)
          : ascii.decode(bytes, allowInvalid: true);
      final cleaned = name.replaceAll('\u0000', '').trim();
      if (cleaned.isNotEmpty) {
        names[nameId]!.add((platformId, languageId, cleaned));
      }
    }

    for (final nameId in [16, 1]) {
      final candidates = names[nameId]!;
      if (candidates.isEmpty) continue;
      candidates.sort((a, b) {
        int score((int, int, String) candidate) {
          final platformId = candidate.$1;
          final languageId = candidate.$2;
          final value = candidate.$3;
          final isAscii = value.codeUnits.every((unit) => unit <= 0x7F);
          return (platformId == 3 && languageId == 0x0409 ? 0 : 4) +
              (isAscii ? 0 : 1);
        }

        return score(a).compareTo(score(b));
      });
      return candidates.first.$3;
    }
    return null;
  }

  static String _decodeUtf16Be(Uint8List bytes) {
    final codePoints = <int>[];
    for (var i = 0; i + 1 < bytes.length; i += 2) {
      final codeUnit = (bytes[i] << 8) | bytes[i + 1];
      if (codeUnit >= 0xD800 && codeUnit <= 0xDBFF && i + 3 < bytes.length) {
        final low = (bytes[i + 2] << 8) | bytes[i + 3];
        if (low >= 0xDC00 && low <= 0xDFFF) {
          codePoints.add(
            0x10000 + ((codeUnit - 0xD800) << 10) + (low - 0xDC00),
          );
          i += 2;
          continue;
        }
      }
      codePoints.add(codeUnit);
    }
    return String.fromCharCodes(codePoints);
  }
}
