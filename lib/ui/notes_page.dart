import 'package:flutter/material.dart';

import '../db/dao.dart';
import '../db/database.dart';
import '../models/note.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final _dao = NotesDao(AppDatabase.instance);
  late Future<List<Note>> _future = _dao.listNotes();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notes')),
      body: FutureBuilder<List<Note>>(
        future: _future,
        builder: (context, snap) {
          final notes = snap.data ?? const <Note>[];
          return ListView.builder(
            itemCount: notes.length,
            itemBuilder: (_, i) {
              final n = notes[i];
              return ListTile(
                title: Text(n.title),
                subtitle: Wrap(
                  spacing: 4,
                  children: [
                    for (final t in n.tags) Chip(label: Text(t)),
                  ],
                ),
                trailing: Text(_fmt(n.updatedAt)),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() {
              _future = _dao.listNotes();
            }),
        child: const Icon(Icons.refresh),
      ),
    );
  }

  String _fmt(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
