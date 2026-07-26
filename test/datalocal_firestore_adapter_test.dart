import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:datalocal/datalocal.dart';
import 'package:datalocal_for_firestore/datalocal_for_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late DataLocalDatabase database;
  late DataLocalCollection<Map<String, Object?>> notes;

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    database = await DataLocalDatabase.open(
      name: 'firestore-adapter-test',
      storage: DataLocalMemoryStorage(),
    );
    notes = database.mapCollection('notes');
  });

  tearDown(() => database.close());

  test(
    'pull materializes Firestore documents without deleting extras',
    () async {
      await firestore.collection('notes').doc('remote-a').set(<String, Object?>{
        'title': 'Remote',
        'updatedAt': Timestamp.fromDate(DateTime.utc(2026, 1, 2)),
      });
      await notes.insert(<String, Object?>{'title': 'Local'}, id: 'local-only');

      final adapter = DataLocalFirestoreAdapter(
        localCollection: notes,
        remoteQuery: firestore.collection('notes'),
      );
      final first = await adapter.pull();

      expect(first.inserted, 1);
      expect(first.updated, 0);
      expect(
        (await notes.require('remote-a')).data['updatedAt'],
        '2026-01-02T00:00:00.000Z',
      );
      expect(await notes.get('local-only'), isNotNull);

      final unchanged = await adapter.pull();
      expect(unchanged.changed, 0);

      await firestore.collection('notes').doc('remote-a').update(
        <String, Object?>{'title': 'Updated'},
      );
      final second = await adapter.pull();
      expect(second.updated, 1);
      expect((await notes.require('remote-a')).data['title'], 'Updated');
    },
  );

  test('watch serializes additions, modifications, and removals', () async {
    final adapter = DataLocalFirestoreAdapter(
      localCollection: notes,
      remoteQuery: firestore.collection('notes'),
    );
    final reports = <DataLocalFirestoreSyncReport>[];
    final subscription = adapter.watch().listen(reports.add);

    await firestore.collection('notes').doc('one').set(<String, Object?>{
      'value': 1,
    });
    await _eventually(() async => await notes.get('one') != null);

    await firestore.collection('notes').doc('one').update(<String, Object?>{
      'value': 2,
    });
    await _eventually(() async => (await notes.get('one'))?.data['value'] == 2);

    await firestore.collection('notes').doc('one').delete();
    await _eventually(() async => await notes.get('one') == null);

    expect(reports.fold<int>(0, (total, report) => total + report.inserted), 1);
    expect(reports.fold<int>(0, (total, report) => total + report.updated), 1);
    expect(reports.fold<int>(0, (total, report) => total + report.deleted), 1);

    await subscription.cancel();
    await adapter.stop();
  });

  test('normalizes nested Firestore-specific values', () {
    final timestamp = Timestamp.fromDate(DateTime.utc(2026, 2, 3, 4, 5));
    final normalized = normalizeFirestoreDocument(<String, Object?>{
      'timestamp': timestamp,
      'point': const GeoPoint(-6.2, 106.8),
      'nested': <String, Object?>{
        'values': <Object?>[timestamp],
      },
    });

    expect(normalized['timestamp'], '2026-02-03T04:05:00.000Z');
    expect(normalized['point'], <String, Object?>{
      'latitude': -6.2,
      'longitude': 106.8,
    });
    expect((normalized['nested']! as Map<String, Object?>)['values'], <Object?>[
      '2026-02-03T04:05:00.000Z',
    ]);
  });
}

Future<void> _eventually(Future<bool> Function() predicate) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (await predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Condition was not met before timeout.');
}
