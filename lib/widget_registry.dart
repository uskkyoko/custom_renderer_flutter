import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// ─── Data model for a remote widget node ────────────────────────────────────
class WidgetNode {
  final String id;
  final String type;
  Map<String, dynamic> props;
  List<String> childIds;
  // Layout from Yoga (sent as { op:"layout", x, y, w, h })
  double x, y, w, h;

  WidgetNode({
    required this.id,
    required this.type,
    required this.props,
    List<String>? childIds,
    this.x = 0,
    this.y = 0,
    this.w = 0,
    this.h = 0,
  }) : childIds = childIds ?? [];
}

// ─── Registry + IPC listener ─────────────────────────────────────────────────
class WidgetRegistry extends ChangeNotifier {
  final Map<String, WidgetNode> _nodes = {};
  String? _rootId;
  WebSocketChannel? _channel;

  String? get rootId => _rootId;
  WidgetNode? node(String id) => _nodes[id];

  // ── Connect to the Node.js WebSocket server ──────────────────────────────
  void connect(String url) {
    _channel = WebSocketChannel.connect(Uri.parse(url));
    debugPrint('[IPC] Connected to $url');

    _channel!.stream.listen(
      (raw) {
        final msg = jsonDecode(raw as String) as Map<String, dynamic>;
        _handleMessage(msg);
      },
      onError: (e) => debugPrint('[IPC] Error: $e'),
      onDone: () => debugPrint('[IPC] Connection closed'),
    );
  }

  // ── Send an event back to React ──────────────────────────────────────────
  void sendEvent(String event, String targetId, [Map<String, dynamic>? extra]) {
    final msg = <String, dynamic>{'event': event, 'targetId': targetId};
    if (extra != null) msg.addAll(extra);
    _channel?.sink.add(jsonEncode(msg));
    debugPrint('[IPC] → sent event: ${jsonEncode(msg)}');
  }

  // ── Message dispatch ─────────────────────────────────────────────────────
  void _handleMessage(Map<String, dynamic> msg) {
    debugPrint('[IPC] ← received: ${jsonEncode(msg)}');
    final op = msg['op'] as String?;
    if (op == null) return;

    switch (op) {
      case 'create':
        _handleCreate(msg);
      case 'appendChild':
        _handleAppendChild(msg);
      case 'removeChild':
        _handleRemoveChild(msg);
      case 'insertBefore':
        _handleInsertBefore(msg);
      case 'update':
        _handleUpdate(msg);
      case 'setText':
        _handleSetText(msg);
      case 'layout':
        _handleLayout(msg);
      default:
        debugPrint('[IPC] Unknown op: $op');
    }

    notifyListeners();
  }

  void _handleCreate(Map<String, dynamic> msg) {
    final id = msg['id'] as String;
    final type = msg['type'] as String;
    final props = (msg['props'] as Map<String, dynamic>?) ?? {};
    _nodes[id] = WidgetNode(id: id, type: type, props: props);
    // The first container becomes the root
    _rootId ??= id;
  }

  void _handleAppendChild(Map<String, dynamic> msg) {
    final parentId = msg['parentId'] as String;
    final childId = msg['childId'] as String;
    // 'root' parentId means top-level
    if (parentId == 'root') {
      _rootId = childId;
    } else {
      _nodes[parentId]?.childIds.add(childId);
    }
  }

  void _handleRemoveChild(Map<String, dynamic> msg) {
    final parentId = msg['parentId'] as String;
    final childId = msg['childId'] as String;
    _nodes[parentId]?.childIds.remove(childId);
    _nodes.remove(childId);
  }

  void _handleInsertBefore(Map<String, dynamic> msg) {
    final parentId = msg['parentId'] as String;
    final childId = msg['childId'] as String;
    final beforeId = msg['beforeId'] as String;
    final parent = _nodes[parentId];
    if (parent == null) return;
    final idx = parent.childIds.indexOf(beforeId);
    if (idx >= 0) {
      parent.childIds.insert(idx, childId);
    } else {
      parent.childIds.add(childId);
    }
  }

  void _handleUpdate(Map<String, dynamic> msg) {
    final id = msg['id'] as String;
    final props = (msg['props'] as Map<String, dynamic>?) ?? {};
    _nodes[id]?.props.addAll(props);
  }

  void _handleSetText(Map<String, dynamic> msg) {
    final id = msg['id'] as String;
    final text = msg['text'] as String? ?? '';
    _nodes[id]?.props['text'] = text;
  }

  void _handleLayout(Map<String, dynamic> msg) {
    final id = msg['id'] as String;
    final node = _nodes[id];
    if (node == null) return;
    node.x = (msg['x'] as num?)?.toDouble() ?? 0;
    node.y = (msg['y'] as num?)?.toDouble() ?? 0;
    node.w = (msg['w'] as num?)?.toDouble() ?? 0;
    node.h = (msg['h'] as num?)?.toDouble() ?? 0;
  }

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }
}
