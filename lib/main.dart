import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'widget_registry.dart';
import 'widget_builder.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => WidgetRegistry(),
      child: const ReactFlutterApp(),
    ),
  );
}

class ReactFlutterApp extends StatefulWidget {
  const ReactFlutterApp({super.key});

  @override
  State<ReactFlutterApp> createState() => _ReactFlutterAppState();
}

class _ReactFlutterAppState extends State<ReactFlutterApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WidgetRegistry>().connect('ws://localhost:9000');
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'React Flutter Renderer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFDD89E3)),
        useMaterial3: true,
      ),
      home: const _RootScreen(),
    );
  }
}

class _RootScreen extends StatelessWidget {
  const _RootScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My App'),
        centerTitle: true,
        backgroundColor: const Color(0xFFDD89E3),
        foregroundColor: Colors.white,
      ),
      body: Consumer<WidgetRegistry>(
        builder: (context, registry, _) {
          final rootId = registry.rootId;

          if (rootId == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 24),
                  Text(
                    'Waiting for React renderer…',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Run: npx tsx index.ts',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ReactWidgetBuilder(nodeId: rootId, registry: registry);
        },
      ),
    );
  }
}
