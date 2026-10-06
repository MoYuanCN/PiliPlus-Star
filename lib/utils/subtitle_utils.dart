import 'package:PiliPlus/models/common/enum_with_label.dart';
import 'package:collection/collection.dart' show IterableExtension;

enum SubtitleFormat implements EnumWithLabel {
  json('JSON'),
  vtt('WEBVTT'),
  srt('SRT');

  @override
  final String label;
  const SubtitleFormat(this.label);
}

abstract final class SubtitleUtils {
  static bool isAss(String value) => RegExp(
    r'^\s*(?:\uFEFF?\[Script Info\]|\[Events\]|Dialogue\s*:)',
    caseSensitive: false,
    multiLine: true,
  ).hasMatch(value);

  static String ass2Vtt(String value) {
    final lines = value
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n');
    var inEvents = false;
    String? eventFormat;
    for (final line in lines) {
      final section = line.trim().toLowerCase();
      if (section.startsWith('[') && section.endsWith(']')) {
        inEvents = section == '[events]';
      } else if (inEvents && section.startsWith('format:')) {
        eventFormat = line;
      }
    }
    final formatLine =
        eventFormat ??
        'Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text';
    final fields = formatLine
        .substring(formatLine.indexOf(':') + 1)
        .split(',')
        .map((field) => field.trim().toLowerCase())
        .toList();
    final startIndex = fields.indexOf('start');
    final endIndex = fields.indexOf('end');
    final textIndex = fields.indexOf('text');
    if (startIndex < 0 || endIndex < 0 || textIndex < 0) return 'WEBVTT\n\n';

    final cues = <({String start, String end, String text})>[];
    for (final line in lines) {
      if (!line.trimLeft().toLowerCase().startsWith('dialogue:')) continue;
      final values = _splitAssFields(
        line.substring(line.indexOf(':') + 1).trimLeft(),
        fields.length,
      );
      if (values.length != fields.length) continue;
      final start = _assTimecode(values[startIndex]);
      final end = _assTimecode(values[endIndex]);
      if (start == null || end == null) continue;

      final rawText = values[textIndex];
      // Vector drawing instructions are not subtitle text.
      if (RegExp(r'\\p[1-9]').hasMatch(rawText)) continue;
      final text = _plainAssText(rawText);
      if (text.isEmpty) continue;
      cues.add((start: start, end: end, text: text));
    }

    final buffer = StringBuffer('WEBVTT\n\n');
    for (final cue in cues) {
      buffer
        ..write(cue.start)
        ..write(' --> ')
        ..write(cue.end)
        ..write('\n')
        ..write(cue.text)
        ..write('\n\n');
    }
    return buffer.toString();
  }

  static String _plainAssText(String value) => value
      .replaceAll(RegExp(r'\{[^}]*\}'), '')
      .replaceAll(r'\N', '\n')
      .replaceAll(r'\n', '\n')
      .replaceAll(r'\h', '\u00a0')
      .trim();

  static List<String> _splitAssFields(String value, int count) {
    final result = <String>[];
    var offset = 0;
    for (var i = 0; i < count - 1; i++) {
      final comma = value.indexOf(',', offset);
      if (comma < 0) return const [];
      result.add(value.substring(offset, comma).trim());
      offset = comma + 1;
    }
    result.add(value.substring(offset).trim());
    return result;
  }

  static String? _assTimecode(String value) {
    final match = RegExp(r'^(\d+):(\d{2}):(\d{2})[.](\d{1,3})$')
        .firstMatch(value.trim());
    if (match == null) return null;
    final hours = int.parse(match[1]!);
    final minutes = int.parse(match[2]!);
    final seconds = int.parse(match[3]!);
    final millis = match[4]!.padRight(3, '0');
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}.$millis';
  }

  static String _vttTimecode(num seconds) {
    final h = (seconds ~/ 3600).toString().padLeft(2, '0');
    seconds %= 3600;
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    seconds %= 60;
    final sms = seconds.toStringAsFixed(3).padLeft(6, '0');
    return "$h:$m:$sms";
  }

  static String json2Vtt(List list) {
    final sb = StringBuffer('WEBVTT\n\n')
      ..writeAll(
        list.map(
          (item) =>
              '${_vttTimecode(item['from'])} --> ${_vttTimecode(item['to'])}\n${_plainAssText(item['content'].toString())}',
        ),
        '\n\n',
      );
    return sb.toString();
  }

  static String _srtTimecode(num seconds) {
    final h = (seconds ~/ 3600).toString().padLeft(2, '0');
    seconds %= 3600;
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    seconds %= 60;
    final s = seconds.toInt();
    final ms = ((seconds - s) * 1000).round().toString().padLeft(3, '0');
    return '$h:$m:${s.toString().padLeft(2, '0')},$ms';
  }

  static String json2Srt(List list) {
    final sb = StringBuffer()
      ..writeAll(
        list.mapIndexed(
          (i, e) =>
              '${i + 1}\n${_srtTimecode(e['from'])} --> ${_srtTimecode(e['to'])}\n${e['content'].trim()}',
        ),
        '\n\n',
      );
    return sb.toString();
  }
}
