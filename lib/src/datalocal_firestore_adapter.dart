import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:datalocal/datalocal.dart';

import 'datalocal_firestore_codec.dart';
import 'datalocal_firestore_sync.dart';

/// Materializes a Firestore query into a DataLocal map collection.
///
/// Remote document IDs are preserved as local IDs. Pulls and realtime changes
/// are applied only after Firestore has successfully returned them. Outbound
/// writes are explicit and are not an offline mutation queue.
final class DataLocalFirestoreAdapter {
  /// Creates a Firestore adapter.
  DataLocalFirestoreAdapter({
    required DataLocalCollection<Map<String, Object?>> localCollection,
    required Query<Map<String, dynamic>> remoteQuery,
  }) : _local = localCollection,
       _query = remoteQuery;

  /// Creates an adapter for a top-level Firestore collection.
  factory DataLocalFirestoreAdapter.collection({
    required DataLocalCollection<Map<String, Object?>> localCollection,
    required String collectionPath,
    FirebaseFirestore? firestore,
  }) {
    final instance = firestore ?? FirebaseFirestore.instance;
    return DataLocalFirestoreAdapter(
      localCollection: localCollection,
      remoteQuery: instance.collection(collectionPath),
    );
  }

  final DataLocalCollection<Map<String, Object?>> _local;
  final Query<Map<String, dynamic>> _query;
  static const _equality = DeepCollectionEquality();
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  Future<void> _pending = Future<void>.value();

  /// Whether a realtime Firestore subscription is active.
  bool get isWatching => _subscription != null;

  /// Fetches the current remote query and upserts its documents locally.
  ///
  /// This method does not delete local documents absent from the result because
  /// the remote query may be filtered or limited.
  Future<DataLocalFirestoreSyncReport> pull() async {
    final snapshot = await _query.get();
    return _upsert(snapshot.docs.map(_document).toList(growable: false));
  }

  /// Starts applying Firestore snapshot changes to the local collection.
  ///
  /// Changes are serialized in snapshot order. A removed query document is
  /// removed from the local materialized view, including when it stops matching
  /// a filtered query.
  Stream<DataLocalFirestoreSyncReport> watch() {
    if (_subscription != null) {
      throw StateError('Firestore synchronization is already active.');
    }
    final controller = StreamController<DataLocalFirestoreSyncReport>();
    _subscription = _query.snapshots().listen(
      (snapshot) {
        _pending = _pending
            .then((_) async {
              final report = await _applyChanges(
                snapshot.docChanges.map(_change).toList(growable: false),
              );
              if (!controller.isClosed) controller.add(report);
            })
            .catchError((Object error, StackTrace stackTrace) {
              if (!controller.isClosed) controller.addError(error, stackTrace);
            });
      },
      onError: controller.addError,
      onDone: controller.close,
    );
    controller.onCancel = stop;
    return controller.stream;
  }

  /// Stops realtime synchronization and drains accepted snapshot changes.
  Future<void> stop() async {
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
    await _pending;
  }

  Future<DataLocalFirestoreSyncReport> _upsert(
    List<DataLocalFirestoreDocument> documents,
  ) async {
    var inserted = 0;
    var updated = 0;
    for (final remote in documents) {
      final current = await _local.get(remote.id);
      if (current == null) {
        await _local.insert(remote.data, id: remote.id);
        inserted++;
      } else if (!_equality.equals(current.data, remote.data)) {
        await _local.replace(
          remote.id,
          remote.data,
          expectedRevision: current.revision,
        );
        updated++;
      }
    }
    return DataLocalFirestoreSyncReport(inserted: inserted, updated: updated);
  }

  Future<DataLocalFirestoreSyncReport> _applyChanges(
    List<DataLocalFirestoreChange> changes,
  ) async {
    var inserted = 0;
    var updated = 0;
    var deleted = 0;
    for (final change in changes) {
      final remote = change.document;
      if (change.type == DataLocalFirestoreChangeType.removed) {
        if (await _local.delete(remote.id)) deleted++;
        continue;
      }
      final current = await _local.get(remote.id);
      if (current == null) {
        await _local.insert(remote.data, id: remote.id);
        inserted++;
      } else if (!_equality.equals(current.data, remote.data)) {
        await _local.replace(
          remote.id,
          remote.data,
          expectedRevision: current.revision,
        );
        updated++;
      }
    }
    return DataLocalFirestoreSyncReport(
      inserted: inserted,
      updated: updated,
      deleted: deleted,
    );
  }

  DataLocalFirestoreDocument _document(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) => DataLocalFirestoreDocument(
    id: document.id,
    data: normalizeFirestoreDocument(document.data()),
  );

  DataLocalFirestoreChange _change(
    DocumentChange<Map<String, dynamic>> change,
  ) => DataLocalFirestoreChange(
    type: switch (change.type) {
      DocumentChangeType.added => DataLocalFirestoreChangeType.added,
      DocumentChangeType.modified => DataLocalFirestoreChangeType.modified,
      DocumentChangeType.removed => DataLocalFirestoreChangeType.removed,
    },
    document: DataLocalFirestoreDocument(
      id: change.doc.id,
      data: normalizeFirestoreDocument(change.doc.data()!),
    ),
  );
}
