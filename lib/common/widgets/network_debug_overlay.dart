import 'dart:math' as math;

import 'package:PiliPlus/utils/network_debug_log.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

class NetworkDebugOverlay extends StatefulWidget {
  const NetworkDebugOverlay({required this.child, super.key});

  final Widget child;

  @override
  State<NetworkDebugOverlay> createState() => _NetworkDebugOverlayState();
}

class _NetworkDebugOverlayState extends State<NetworkDebugOverlay> {
  bool _visible = false;
  Offset _position = const Offset(24, 72);
  int? _selectedId;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey == LogicalKeyboardKey.f1) {
      if (!_visible) setState(() => _visible = true);
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.f2) {
      if (_visible) setState(() => _visible = false);
      return true;
    }
    return false;
  }

  void _moveWindow(Offset delta, Size viewport, double width, double height) {
    setState(() {
      _position = Offset(
        (_position.dx + delta.dx).clamp(
          8.0,
          math.max(8.0, viewport.width - width - 8),
        ),
        (_position.dy + delta.dy).clamp(
          8.0,
          math.max(8.0, viewport.height - height - 8),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      widget.child,
      if (_visible)
        LayoutBuilder(
          builder: (context, constraints) {
            final viewport = Size(constraints.maxWidth, constraints.maxHeight);
            final width = math
                .min(940.0, math.max(280.0, viewport.width - 24))
                .toDouble();
            final height = math
                .min(
                  720.0,
                  math.max(260.0, viewport.height - 24),
                )
                .toDouble();
            final left = _position.dx
                .clamp(
                  8.0,
                  math.max(8.0, viewport.width - width - 8),
                )
                .toDouble();
            final top = _position.dy
                .clamp(
                  8.0,
                  math.max(8.0, viewport.height - height - 8),
                )
                .toDouble();
            return Positioned(
              left: left,
              top: top,
              width: width,
              height: height,
              child: _NetworkDebugWindow(
                onDrag: (delta) => _moveWindow(delta, viewport, width, height),
                onClose: () => setState(() => _visible = false),
                selectedId: _selectedId,
                onSelect: (id) => setState(() => _selectedId = id),
                onClear: () {
                  NetworkDebugLog.clear();
                  setState(() => _selectedId = null);
                },
              ),
            );
          },
        ),
    ],
  );
}

class _NetworkDebugWindow extends StatelessWidget {
  const _NetworkDebugWindow({
    required this.onDrag,
    required this.onClose,
    required this.selectedId,
    required this.onSelect,
    required this.onClear,
  });

  final ValueChanged<Offset> onDrag;
  final VoidCallback onClose;
  final int? selectedId;
  final ValueChanged<int> onSelect;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 16,
      color: theme.colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (details) => onDrag(details.delta),
            child: ColoredBox(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  const Icon(Icons.network_check, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '实验性网络日志',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  ValueListenableBuilder<List<NetworkDebugEntry>>(
                    valueListenable: NetworkDebugLog.entries,
                    builder: (context, entries, _) => Text(
                      '最近 ${entries.length} 条（仅保存在内存）',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  IconButton(
                    tooltip: '清空日志',
                    onPressed: onClear,
                    icon: const Icon(Icons.delete_sweep_outlined),
                  ),
                  IconButton(
                    tooltip: '关闭（F2）',
                    onPressed: onClose,
                    icon: const Icon(Icons.close),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ValueListenableBuilder<List<NetworkDebugEntry>>(
              valueListenable: NetworkDebugLog.entries,
              builder: (context, entries, _) {
                final selected =
                    entries
                        .where((entry) => entry.id == selectedId)
                        .firstOrNull ??
                    entries.firstOrNull;
                return Row(
                  children: [
                    SizedBox(
                      width: math.min(
                        300.0,
                        MediaQuery.sizeOf(context).width * .34,
                      ),
                      child: entries.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Text(
                                  '尚无网络请求。打开番剧后开始播放，再按 F1 查看请求和响应。',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: entries.length,
                              itemBuilder: (context, index) {
                                final entry = entries[index];
                                final isSelected = entry.id == selected?.id;
                                return ListTile(
                                  dense: true,
                                  selected: isSelected,
                                  onTap: () => onSelect(entry.id),
                                  title: Text(
                                    entry.kind == 'HTTP'
                                        ? '${entry.method}  ${entry.statusCode ?? (entry.isComplete ? 'ERR' : '…')}'
                                        : '${entry.kind}  ${entry.method}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    '${entry.url}\n${entry.durationMs == null ? (entry.isComplete ? '已记录' : '进行中') : '${entry.durationMs} ms'}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              },
                            ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: selected == null
                          ? const SizedBox.shrink()
                          : _NetworkDebugDetails(entry: selected),
                    ),
                  ],
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'F1 打开 · F2 关闭 · Cookie、令牌、签名和账号标识已脱敏',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NetworkDebugDetails extends StatelessWidget {
  const _NetworkDebugDetails({required this.entry});

  final NetworkDebugEntry entry;

  @override
  Widget build(BuildContext context) {
    if (entry.kind != 'HTTP') {
      return Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: SelectionArea(
            child: Text(
              '时间：${entry.startedAt.toIso8601String()}\n'
              '${entry.kind} ${entry.method}\n${entry.url}\n\n'
              '日志\n${entry.responseBody}',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
      );
    }
    final status = entry.statusCode == null
        ? (entry.isComplete ? '请求失败' : '等待响应')
        : 'HTTP ${entry.statusCode}';
    final error = entry.error.isEmpty ? '' : '\n错误：${entry.error}';
    final details = StringBuffer()
      ..writeln('时间：${entry.startedAt.toIso8601String()}')
      ..writeln('${entry.method} $status · ${entry.durationMs ?? '…'} ms')
      ..writeln(entry.url)
      ..writeln('\n请求 Headers\n${entry.requestHeaders}')
      ..writeln('\nQuery 参数\n${entry.query}')
      ..writeln('\n请求 Body\n${entry.requestBody}')
      ..writeln(
        '\n响应 Headers\n${entry.responseHeaders.isEmpty ? '(暂无)' : entry.responseHeaders}',
      )
      ..writeln(
        '\n响应 Body\n${entry.responseBody.isEmpty ? '(暂无)' : entry.responseBody}',
      )
      ..write(error);

    return Scrollbar(
      thumbVisibility: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: SelectionArea(
          child: Text(
            details.toString(),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
      ),
    );
  }
}
