import 'package:flutter/material.dart';

/// Stand-in for a module that is not built yet. It also prints the context it
/// received (route params), which proves Home passes the right data on.
class ComingSoonPage extends StatelessWidget {
  const ComingSoonPage({super.key, required this.title, required this.module, this.params = const {}});

  final String title;
  final String module;
  final Map<String, String> params;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.construction_rounded, size: 56),
            const SizedBox(height: 12),
            Text('$title arrives with $module', textAlign: TextAlign.center),
            if (params.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Received context:', style: TextStyle(fontWeight: FontWeight.w700)),
              for (final e in params.entries) Text('${e.key} = ${e.value}'),
            ],
          ]),
        ),
      ),
    );
  }
}
