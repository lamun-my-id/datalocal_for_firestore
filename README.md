# DataLocal for Firestore

Firestore synchronization and local materialized views powered by
[DataLocal](https://pub.dev/packages/datalocal).

This package does not replace Firestore's SDK or silently synchronize every
DataLocal collection. It explicitly materializes one Firestore query into one
local DataLocal collection.

## Install

```yaml
dependencies:
  datalocal: ^2.0.0
  datalocal_for_firestore: ^2.0.0
```

Initialize Firebase normally, then open DataLocal using either its
SharedPreferences adapter or `datalocal_sqlite`:

```dart
final database = await DataLocalDatabase.open(
  name: 'my_app',
  storage: DataLocalSharedPreferencesAsyncStorage(),
);

final localNotes = database.mapCollection('notes');
final sync = DataLocalFirestoreAdapter.collection(
  localCollection: localNotes,
  collectionPath: 'notes',
);
```

## One-time pull

```dart
final report = await sync.pull();
print('Changed ${report.changed} local documents');

final cached = await localNotes
    .query()
    .where('completed', isEqualTo: false)
    .orderBy('title')
    .get();
```

A pull upserts returned documents but does not delete local documents absent
from the result, because the Firestore query may be filtered or limited.

## Realtime materialized view

```dart
final reports = sync.watch().listen((report) {
  print('Firestore changed ${report.changed} cached documents');
});

// Read and watch through DataLocal while remote snapshots update the cache.
final localSnapshots = localNotes.query().watch().listen((snapshot) {
  print('${snapshot.documents.length} locally available notes');
});

await reports.cancel();
await sync.stop();
await localSnapshots.cancel();
await database.close();
```

For a filtered Firestore query, a `removed` snapshot means the document is
removed from that local materialized view. It may have been deleted remotely or
simply stopped matching the query.

## Custom Firestore queries and Firebase apps

```dart
final query = FirebaseFirestore.instanceFor(app: secondaryApp)
    .collection('notes')
    .where('ownerId', isEqualTo: userId)
    .orderBy('updatedAt', descending: true)
    .limit(100);

final sync = DataLocalFirestoreAdapter(
  localCollection: localNotes,
  remoteQuery: query,
);
```

Firestore timestamps are normalized to UTC ISO-8601 strings. GeoPoints become
`{latitude, longitude}` maps, document references become paths, and blobs
become base64 strings before DataLocal persists them.

## Current scope

Version 2 starts with remote-to-local pull and realtime reconciliation. It does
not yet include an offline outbound mutation queue, automatic retry,
tombstones, or conflict resolution. Continue using Firestore's write APIs for
remote mutations until those semantics are introduced explicitly.

Use a per-user DataLocal database or collection namespace and clear it during
logout. Never expose one user's cached materialized view to another user.
