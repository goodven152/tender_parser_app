import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext ctx) => MaterialApp(
    title: 'Parser Admin',
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
    home: const HomePage(),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePage();
}

class _HomePage extends State<HomePage> {
  final _channel = WebSocketChannel.connect(
    Uri.parse('ws://${Uri.base.host}:8000/ws'),
  );
  double _progress = 0;
  List<Map<String, dynamic>> _runs = [];
  List<String> _keywords = [];

  @override
  void initState() {
    super.initState();
    _refresh();
    _channel.stream.listen((msg) {
      final data = json.decode(msg);
      setState(() => _progress = data['progress'] / 100.0);
    });
  }

  Future<void> _refresh() async {
    final r = await http.get(Uri.parse('/runs'));
    _runs = List<Map<String, dynamic>>.from(json.decode(r.body));
    final kw = await http.get(Uri.parse('/keywords'));
    _keywords = List<String>.from(json.decode(kw.body)['KEYWORDS_GEO']);
    setState(() => {});
  }

  Future<void> _run() async {
    await http.post(Uri.parse('/run'));
  }

  Future<void> _saveKW() async {
    await http.put(
      Uri.parse('/keywords'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(_keywords),
    );
  }

  @override
  Widget build(BuildContext ctx) => Scaffold(
    appBar: AppBar(title: const Text('Parser Admin')),
    body: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              ElevatedButton(onPressed: _run, child: const Text('Run now')),
              const SizedBox(width: 20),
              _progress > 0
                  ? Expanded(child: LinearProgressIndicator(value: _progress))
                  : const SizedBox(),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Last runs',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: ListView(
              children:
                  _runs
                      .map(
                        (r) => ListTile(
                          title: Text(r['started']),
                          subtitle: Text(r['returncode'] == 0 ? 'OK' : 'ERROR'),
                          trailing: Text('${(r['returncode'] ?? '')}'),
                        ),
                      )
                      .toList(),
            ),
          ),
          const Divider(),
          const Text(
            'Keywords',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _keywords.length,
              itemBuilder:
                  (_, i) => ListTile(
                    title: TextFormField(
                      initialValue: _keywords[i],
                      onChanged: (v) => _keywords[i] = v,
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () {
                        setState(() => _keywords.removeAt(i));
                      },
                    ),
                  ),
            ),
          ),
          ElevatedButton(
            onPressed: _saveKW,
            child: const Text('Save keywords'),
          ),
        ],
      ),
    ),
  );
}
