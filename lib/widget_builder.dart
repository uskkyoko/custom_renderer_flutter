// lib/widget_builder.dart
// Recursively turns WidgetNode trees into real Flutter widgets.
// Each React element type maps to a Flutter primitive:
//
//  container  → Column or Row (based on flexDirection prop)
//  text       → Text widget
//  button     → ElevatedButton / OutlinedButton / TextButton
//  listitem   → a Row-based list tile
//  input      → TextField

import 'package:flutter/material.dart';
import 'widget_registry.dart';

class ReactWidgetBuilder extends StatelessWidget {
  final String nodeId;
  final WidgetRegistry registry;

  const ReactWidgetBuilder({
    super.key,
    required this.nodeId,
    required this.registry,
  });

  @override
  Widget build(BuildContext context) {
    final node = registry.node(nodeId);
    if (node == null) return const SizedBox.shrink();

    return switch (node.type) {
      'container' => _buildContainer(context, node),
      'text'      => _buildText(context, node),
      'button'    => _buildButton(context, node),
      'listitem'  => _buildListItem(context, node),
      'input'     => _buildInput(context, node),
      _           => _buildUnknown(node),
    };
  }

  // ── container → Column / Row ───────────────────────────────────────────────
  Widget _buildContainer(BuildContext context, WidgetNode node) {
    final isRow = node.props['flexDirection'] == 'row';
    final padding = (node.props['padding'] as num?)?.toDouble() ?? 0;
    final children = node.childIds
        .map((id) => ReactWidgetBuilder(nodeId: id, registry: registry))
        .toList();

    final mainAxis = _mainAxisAlignment(node.props['justifyContent']);
    final crossAxis = _crossAxisAlignment(node.props['alignItems']);

    Widget box = isRow
        ? Row(mainAxisAlignment: mainAxis, crossAxisAlignment: crossAxis, children: children)
        : Column(mainAxisAlignment: mainAxis, crossAxisAlignment: crossAxis, children: children);

    if (padding > 0) box = Padding(padding: EdgeInsets.all(padding), child: box);

    // Apply Yoga-computed size if available
    if (node.w > 0 || node.h > 0) {
      box = SizedBox(
        width: node.w > 0 ? node.w : null,
        height: node.h > 0 ? node.h : null,
        child: box,
      );
    }

    // flex prop → Expanded
    if (node.props['flex'] != null) {
      box = Expanded(flex: (node.props['flex'] as num).toInt(), child: box);
    }

    return box;
  }

  // ── text → Text ───────────────────────────────────────────────────────────
  Widget _buildText(BuildContext context, WidgetNode node) {
    final rawText = node.props['text'] as String? ??
        node.props['children'] as String? ?? '';
    final style = node.props['style'] as Map<String, dynamic>? ?? {};

    return Text(
      rawText,
      style: TextStyle(
        fontSize: (style['fontSize'] as num?)?.toDouble(),
        fontWeight: style['fontWeight'] == 'bold' ? FontWeight.bold : null,
        color: _parseColor(style['color'] as String?),
        decoration: style['textDecoration'] == 'line-through'
            ? TextDecoration.lineThrough
            : null,
      ),
    );
  }

  // ── button → ElevatedButton / OutlinedButton / TextButton ─────────────────
  Widget _buildButton(BuildContext context, WidgetNode node) {
    final label = node.props['label'] as String? ?? '';
    final variant = node.props['variant'] as String? ?? 'text';
    final colorStr = node.props['color'] as String?;
    final fgColor = colorStr == 'error'
        ? Colors.red
        : colorStr == 'primary'
            ? Theme.of(context).colorScheme.primary
            : null;

    void onPressed() => registry.sendEvent('click', node.id);
    final child = Text(label);

    return switch (variant) {
      'filled'   => ElevatedButton(onPressed: onPressed, style: fgColor != null
          ? ElevatedButton.styleFrom(foregroundColor: fgColor) : null, child: child),
      'outlined' => OutlinedButton(onPressed: onPressed, child: child),
      _          => TextButton(onPressed: onPressed, child: child),
    };
  }

  // ── listitem → Row with leading, text, trailing ───────────────────────────
  Widget _buildListItem(BuildContext context, WidgetNode node) {
    final padding = (node.props['padding'] as num?)?.toDouble() ?? 8;
    final children = node.childIds
        .map((id) => ReactWidgetBuilder(nodeId: id, registry: registry))
        .toList();

    return Padding(
      padding: EdgeInsets.symmetric(vertical: padding / 2),
      child: Row(children: children),
    );
  }

  // ── input → TextField ─────────────────────────────────────────────────────
  Widget _buildInput(BuildContext context, WidgetNode node) {
    final placeholder = node.props['placeholder'] as String? ?? '';
    // Note: For a real renderer you'd use a TextEditingController synced
    // with React state via IPC change events.
    return Expanded(
      child: TextField(
        decoration: InputDecoration(hintText: placeholder, border: const OutlineInputBorder()),
        onChanged: (val) => registry.sendEvent('change', node.id, {'value': val}),
      ),
    );
  }

  // ── fallback ──────────────────────────────────────────────────────────────
  Widget _buildUnknown(WidgetNode node) {
    return Text('[unknown: ${node.type}]', style: const TextStyle(color: Colors.red));
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  MainAxisAlignment _mainAxisAlignment(dynamic val) => switch (val) {
        'center'        => MainAxisAlignment.center,
        'space-between' => MainAxisAlignment.spaceBetween,
        'flex-end'      => MainAxisAlignment.end,
        _               => MainAxisAlignment.start,
      };

  CrossAxisAlignment _crossAxisAlignment(dynamic val) => switch (val) {
        'center'   => CrossAxisAlignment.center,
        'flex-end' => CrossAxisAlignment.end,
        _          => CrossAxisAlignment.start,
      };

  Color? _parseColor(String? hex) {
    if (hex == null) return null;
    if (hex == '#888' || hex == '#888888') return Colors.grey;
    if (hex == '#aaa' || hex == '#aaaaaa') return Colors.grey.shade400;
    if (hex == '#ccc' || hex == '#cccccc') return Colors.grey.shade300;
    if (hex == '#4CAF50') return const Color(0xFF4CAF50);
    if (hex.startsWith('#') && hex.length == 7) {
      return Color(int.parse('FF${hex.substring(1)}', radix: 16));
    }
    return null;
  }
}
