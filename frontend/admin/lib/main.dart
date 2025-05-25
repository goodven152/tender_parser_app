import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

/// Simple admin panel for GETenders parser backend
/// Covers full public API:
///   • POST /run (trigger run)
///   • WS  /ws  (live progress & log)
///   • GET /runs (history)
///   • GET /next_run (next scheduled run)
///   • GET/PUT /keywords (edit keywords list)
///   • GET/PUT /config   (edit complete config.json)
void main() => runApp(const MyApp());

// ──────────────────────────────────────────────────────────────────────────
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Parser Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: const HomePage(),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // ——— State ———
  final _channel = WebSocketChannel.connect(
    Uri.parse('ws://${Uri.base.host}:8000/ws'),
  );
  double _progress = 0;
  String? _runId;
  List<Map<String, dynamic>> _runs = [];
  List<String> _keywords = [];
  DateTime? _nextRunUtc;
  Timer? _pollTimer;

  // ——— Lifecycle ———
  @override
  void initState() {
    super.initState();
    _refreshAll();

    // listen WS for progress updates
    _channel.stream.listen((msg) {
      final data = json.decode(msg);
      if (mounted) {
        setState(() {
          _runId = data['id'] as String?;
          _progress = (data['progress'] as num).toDouble() / 100.0;
        });
      }
    });

    // periodic polling of history / nextRun (every 30 s)
    _pollTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refreshAll(),
    );
  }

  @override
  void dispose() {
    _channel.sink.close();
    _pollTimer?.cancel();
    super.dispose();
  }

  // ——— API helpers ———
  Uri _u(String path) => Uri.parse('http://${Uri.base.host}:8000$path');

  Future<void> _refreshAll() async {
    await Future.wait([_fetchRuns(), _fetchKeywords(), _fetchNextRun()]);
  }

  Future<void> _fetchRuns() async {
    final r = await http.get(_u('/runs'));
    if (r.statusCode == 200) {
      setState(
        () => _runs = List<Map<String, dynamic>>.from(json.decode(r.body)),
      );
    }
  }

  Future<void> _fetchKeywords() async {
    final r = await http.get(_u('/keywords'));
    if (r.statusCode == 200) {
      setState(
        () =>
            _keywords = List<String>.from(json.decode(r.body)['KEYWORDS_GEO']),
      );
    }
  }

  Future<void> _fetchNextRun() async {
    final r = await http.get(_u('/next_run'));
    if (r.statusCode == 200) {
      final iso = json.decode(r.body)['next'] as String?;
      setState(
        () => _nextRunUtc = iso != null ? DateTime.parse(iso).toLocal() : null,
      );
    }
  }

  Future<void> _triggerRun() async {
    await http.post(_u('/run'));
  }

  Future<void> _saveKeywords() async {
    await http.put(
      _u('/keywords'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(_keywords),
    );
  }

  Future<void> _editConfig() async {
    // fetch current config
    final r = await http.get(_u('/config'));
    if (r.statusCode != 200) return;
    final controller = TextEditingController(
      text: const JsonEncoder.withIndent('  ').convert(json.decode(r.body)),
    );

    final saved = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Edit config.json'),
            content: SizedBox(
              width: 600,
              child: Scrollbar(
                thumbVisibility: true,
                child: SingleChildScrollView(
                  child: TextField(
                    controller: controller,
                    maxLines: null,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save'),
              ),
            ],
          ),
    );

    if (saved == true) {
      try {
        final cfg = json.decode(controller.text);
        final res = await http.put(
          _u('/config'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(cfg),
        );
        if (res.statusCode == 200) {
          if (mounted)
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Config saved')));
        } else {
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed: ${res.statusCode}')),
            );
        }
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('JSON error: $e')));
      }
    }
  }

  // ——— UI widgets ———

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Parser Admin')),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // row 1 — action buttons & progress
            Row(
              children: [
                FilledButton.icon(
                  onPressed: _triggerRun,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Run now'),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _editConfig,
                  icon: const Icon(Icons.edit_document),
                  label: const Text('Edit config'),
                ),
                const SizedBox(width: 24),
                if (_runId != null) ...[
                  Expanded(child: LinearProgressIndicator(value: _progress)),
                  const SizedBox(width: 8),
                  Text('${(_progress * 100).toStringAsFixed(0)} %'),
                ],
              ],
            ),
            const SizedBox(height: 12),
            if (_nextRunUtc != null)
              Text(
                'Next scheduled run: ${_fmtDateTime(_nextRunUtc!)}',
                style: theme.textTheme.bodyMedium,
              ),
            const Divider(height: 32),

            // history
            Text('Last runs', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            _runs.isEmpty
                ? const Text('No runs yet')
                : DataTable(
                  columnSpacing: 12,
                  headingRowHeight: 32,
                  columns: const [
                    DataColumn(label: Text('Start')),
                    DataColumn(label: Text('End')),
                    DataColumn(label: Text('Status')),
                  ],
                  rows: _runs.map(_runRow).toList(),
                ),
            const Divider(height: 32),

            // keywords
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Keywords', style: theme.textTheme.titleMedium),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'Add keyword',
                  onPressed: () => setState(() => _keywords.add('')),
                ),
              ],
            ),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _keywords.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex -= 1;
                  final item = _keywords.removeAt(oldIndex);
                  _keywords.insert(newIndex, item);
                });
              },
              itemBuilder:
                  (ctx, i) => ListTile(
                    key: ValueKey('kw_$i'),
                    title: TextFormField(
                      initialValue: _keywords[i],
                      onChanged: (v) => _keywords[i] = v,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => setState(() => _keywords.removeAt(i)),
                    ),
                  ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _saveKeywords,
                icon: const Icon(Icons.save),
                label: const Text('Save keywords'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  DataRow _runRow(Map<String, dynamic> r) {
    final started =
        r['started'] != null ? DateTime.parse(r['started']).toLocal() : null;
    final finished =
        r['finished'] != null ? DateTime.parse(r['finished']).toLocal() : null;
    final ok = (r['returncode'] as int?) == 0;

    return DataRow(
      cells: [
        DataCell(Text(started != null ? _fmtDateTime(started) : '-')),
        DataCell(Text(finished != null ? _fmtDateTime(finished) : '-')),
        DataCell(
          Row(
            children: [
              Icon(
                ok ? Icons.check_circle : Icons.error,
                size: 16,
                color: ok ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 4),
              Text(ok ? 'OK' : 'Error'),
            ],
          ),
        ),
      ],
    );
  }

  String _fmtDateTime(DateTime dt) =>
      '${dt.year}-${_two(dt.month)}-${_two(dt.day)} ${_two(dt.hour)}:${_two(dt.minute)}';
  String _two(int n) => n.toString().padLeft(2, '0');
}
