import 'dart:async';

import 'package:datalocal/datalocal.dart';
import 'package:datalocal_for_firestore/datalocal_for_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  final database = await DataLocalDatabase.open(
    name: 'firestore-example',
    storage: DataLocalSharedPreferencesAsyncStorage(),
  );
  runApp(FirestoreExample(database: database));
}

class FirestoreExample extends StatelessWidget {
  const FirestoreExample({super.key, required this.database});

  final DataLocalDatabase database;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'DataLocal for Firestore',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
          useMaterial3: true,
        ),
        home: NotesPage(database: database),
      );
}

class NotesPage extends StatefulWidget {
  const NotesPage({super.key, required this.database});

  final DataLocalDatabase database;

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  late final DataLocalCollection<Map<String, Object?>> _notes;
  late final DataLocalFirestoreAdapter _sync;
  StreamSubscription<DataLocalQuerySnapshot<Map<String, Object?>>>?
      _localSubscription;
  StreamSubscription<DataLocalFirestoreSyncReport>? _remoteSubscription;
  List<DataLocalDocument<Map<String, Object?>>> _documents = const [];
  String _status = 'Ready';

  @override
  void initState() {
    super.initState();
    _notes = widget.database.mapCollection('notes');
    _sync = DataLocalFirestoreAdapter.collection(
      localCollection: _notes,
      collectionPath: 'notes',
    );
    _localSubscription = _notes.query().orderBy('title').watch().listen((
      snapshot,
    ) {
      if (mounted) setState(() => _documents = snapshot.documents);
    });
  }

  Future<void> _pull() async {
    setState(() => _status = 'Pulling…');
    final report = await _sync.pull();
    if (mounted) setState(() => _status = 'Changed ${report.changed} docs');
  }

  void _watch() {
    if (_remoteSubscription != null) return;
    _remoteSubscription = _sync.watch().listen((report) {
      if (mounted) {
        setState(() => _status = 'Realtime changed ${report.changed} docs');
      }
    });
    setState(() => _status = 'Realtime active');
  }

  @override
  void dispose() {
    unawaited(_remoteSubscription?.cancel());
    unawaited(_localSubscription?.cancel());
    unawaited(_sync.stop());
    unawaited(widget.database.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Firestore materialized view')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  FilledButton(
                      onPressed: _pull, child: const Text('Pull once')),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: _watch,
                    child: const Text('Start realtime'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_status)),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _documents.length,
                itemBuilder: (context, index) {
                  final document = _documents[index];
                  return ListTile(
                    title:
                        Text(document.data['title']?.toString() ?? document.id),
                    subtitle: Text(document.id),
                  );
                },
              ),
            ),
          ],
        ),
      );
}
