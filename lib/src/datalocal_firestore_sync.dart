/// Kind of change received from a remote Firestore query.
enum DataLocalFirestoreChangeType { added, modified, removed }

/// Firestore document normalized into values supported by DataLocal.
final class DataLocalFirestoreDocument {
  /// Creates a normalized remote document.
  const DataLocalFirestoreDocument({required this.id, required this.data});

  /// Firestore document identifier.
  final String id;

  /// Document fields after Firestore-specific values have been normalized.
  final Map<String, Object?> data;
}

/// One change in a Firestore snapshot.
final class DataLocalFirestoreChange {
  /// Creates a remote change.
  const DataLocalFirestoreChange({required this.type, required this.document});

  /// Change kind reported by Firestore.
  final DataLocalFirestoreChangeType type;

  /// Changed document.
  final DataLocalFirestoreDocument document;
}

/// Result of applying a remote snapshot to a local collection.
final class DataLocalFirestoreSyncReport {
  /// Creates a synchronization report.
  const DataLocalFirestoreSyncReport({
    this.inserted = 0,
    this.updated = 0,
    this.deleted = 0,
  });

  /// Number of documents inserted locally.
  final int inserted;

  /// Number of documents replaced locally.
  final int updated;

  /// Number of documents deleted locally.
  final int deleted;

  /// Total number of local mutations.
  int get changed => inserted + updated + deleted;
}
