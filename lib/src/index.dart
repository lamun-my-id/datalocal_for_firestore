// ignore_for_file: no_wildcard_variable_uses

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:datalocal/datalocal.dart';
import 'package:datalocal/utils/compute.dart';
import 'package:datalocal/utils/encrypt.dart';
import 'package:datalocal_for_firestore/datalocal_for_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:datalocal_for_firestore/src/utils/date_time_util.dart';
import 'package:datalocal_for_firestore/src/utils/firestore_util.dart';
import 'package:datalocal_for_firestore/src/extensions/list_data_item.dart';

class DataLocalForFirestore extends DataLocal {
  String collectionPath;

  DataLocalForFirestore(
    super.stateName, {
    super.onRefresh,
    super.debugMode,
    required this.collectionPath,
  }) : _debugMode = debugMode;

  // Static Func
  /// Used for the first time initialize [DataLocalForFirestore]
  static Future<DataLocalForFirestore> stream(
    String stateName, {
    Function()? onRefresh,
    bool? debugMode,
    required String collectionPath,
    List<DataSort>? sorts,
    List<DataFilter>? filters,
    int size = 100,
  }) async {
    DataLocalForFirestore result = DataLocalForFirestore(
      stateName,
      onRefresh: onRefresh,
      debugMode: debugMode ?? false,
      collectionPath: collectionPath,
    );
    result._sorts = sorts;
    result._filters = filters;
    result._size = size;
    await result._initialize();
    return result;
  }

  List<DataSort>? _sorts;
  List<DataFilter>? _filters;

  late String _name;

  late int _size;

  final bool _debugMode;
  late DataContainer _container;
  // DataContainer get container => _container;

  bool _isLoading = false;
  @override
  bool get isLoading => _isLoading;

  bool _isInit = false;
  @override
  bool get isInit => _isInit;

  int _count = 0;
  @override
  int get count => _count;

  final Map<String, DataItem> _raw = {};
  // Map<String, DataItem> get raw => _raw;

  /// Log DataLocal used on debugMode
  _log(dynamic arg) async {
    if (_debugMode) {
      debugPrint('DataLocal (Debug): ${arg.toString()}');
    }
  }

  Future<void> _initialize() async {
    try {
      _name = EncryptUtil().encript(
        "DataLocalForFirestore-$stateName",
      );
      bool firstTime = true;
      try {
        String? res;
        try {
          final SharedPreferences prefs = await SharedPreferences.getInstance();
          res = (prefs.getString(EncryptUtil().encript(_name)));
        } catch (e) {
          _log("error get res");
        }

        if (res == null) {
          _container = DataContainer(
            name: _name,
            seq: 0,
            ids: [],
          );
          throw "tidak ada state";
        } else {
          firstTime = false;
          _container =
              DataContainer.fromMap(jsonDecode(EncryptUtil().decript(res)));
        }

        if (_container.ids.isNotEmpty) {
          await _loadState();
        }
      } catch (e) {
        _log("initialize error(2)#$stateName : $e");
      }
      _isInit = true;
      refresh();
      // print("========================${_container.ids.length}");
      if (firstTime || _container.ids.isEmpty) {
        // print(
        //     'pertama kali atau actualCount tidak sesuai, ${_container.ids.length}');
        await _presync();
      } else {
        if ((_container.params['actualCount'] ?? 0) != _container.ids.length) {
          await _syncCounter();
        }
        // print('bukan pertama kalo skip synckon, ${_container.ids.length}');
      }
      // print("object state berhasil di load ============");
      if ((_container.params['actualCount'] ?? 0) != _container.ids.length) {
        _sync().then((_) async {
          // print('=======sync berhasil');
          await _saveState();
          // print('=======save');
          _stream();
        });
      } else {
        _stream();
      }
      refresh();
    } catch (e) {
      _log("initialize error(1) : $e");
      //
    }
  }

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _newStream;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _updateStream;

  Future<void> _stream() async {
    // print("Stream started");
    try {
      _streamNews();
    } catch (e) {
      // print(e);
      //
    }

    try {
      _streamUpdates();
    } catch (e) {
      // print(e);
      // _log("error update");
    }
  }

  Future<void> _streamNews() async {
    try {
      List<DataFilter>? filterUpdate = [];
      if (_filters != null) {
        for (DataFilter filter in _filters!) {
          if (filter.key.key != "updatedAt" &&
              filter.key.key != "createdAt" &&
              filter.key.key != 'deletedAt') {
            filterUpdate.add(filter);
          }
        }
      }
      filterUpdate.add(DataFilter(
        "createdAt",
        value: _container.lastDataCreatedAt,
        operator: DataFilterOperator.isGreaterThan,
      ));
      _newStream = FirestoreUtil()
          .queryBuilder(
            collectionPath,
            sorts: [
              DataSort(
                "createdAt",
                desc: true,
              ),
            ],
            filters: filterUpdate,
          )
          .snapshots()
          .listen((event) async {
        if (event.docs.isNotEmpty) {
          for (DocumentSnapshot<Map<String, dynamic>> doc in event.docs) {
            DataItem element = DataItem.fromMap({
              "id": doc.id,
              "data": doc.data(),
              "name": stateName,
              "parent": collectionPath,
              "createdAt": DateTimeUtils.toDateTime(doc.data()!['createdAt']),
              "updatedAt": DateTimeUtils.toDateTime(doc.data()!['updatedAt']),
              "deletedAt": DateTimeUtils.toDateTime(doc.data()!['deletedAt']),
            });
            try {
              _raw[doc.id] = element;
              _container.ids.add(element.path());
              await _raw[doc.id]!.save({});
            } catch (e) {
              _log("newStream error(1) : $e");
            }
          }
          _container.lastDataCreatedAt =
              DateTimeUtils.toDateTime(event.docs.first['createdAt']);
          _newStream?.cancel();
          _streamNews();
          _syncCounter();
          _log("new Stream available, ${_container.lastDataCreatedAt}");
        } else {
          _log("new Stream unavailable, ${_container.lastDataCreatedAt}");
        }
      });
    } catch (e) {
      _log("newStream error(2) : $e");
    }
  }

  Future<void> _streamUpdates() async {
    try {
      List<DataFilter>? filterUpdate = [];
      if (_filters != null) {
        for (DataFilter filter in _filters!) {
          if (filter.key.key != "updatedAt" &&
              filter.key.key != "createdAt" &&
              filter.key.key != 'deletedAt') {
            filterUpdate.add(filter);
          }
        }
      }
      filterUpdate.add(DataFilter(
        "updatedAt",
        value: _container.lastDataUpdatedAt,
        operator: DataFilterOperator.isGreaterThan,
      ));
      // _log('start stream $collectionPath');
      _updateStream = FirestoreUtil()
          .queryBuilder(
            collectionPath,
            sorts: [
              DataSort(
                "updatedAt",
                desc: true,
              ),
            ],
            filters: filterUpdate,
          )
          .snapshots()
          .listen((event) async {
        // _log('listen stream $collectionPath');
        if (event.docs.isNotEmpty) {
          for (DocumentSnapshot<Map<String, dynamic>> doc in event.docs) {
            DataItem element = DataItem.fromMap({
              "id": doc.id,
              "data": doc.data(),
              "name": stateName,
              "parent": collectionPath,
              "createdAt": DateTimeUtils.toDateTime(doc.data()!['createdAt']),
              "updatedAt": DateTimeUtils.toDateTime(doc.data()!['updatedAt']),
              "deletedAt": DateTimeUtils.toDateTime(doc.data()!['deletedAt']),
            });
            try {
              _raw[doc.id] = element;
              await _raw[doc.id]!.save({});
            } catch (e) {
              _log("newStream error(1) : $e");
              //
            }
          }
          _count = _container.ids.length;
          _container.lastDataUpdatedAt =
              DateTimeUtils.toDateTime(event.docs.first['updatedAt']);
          _updateStream?.cancel();
          _streamUpdates();
          _syncCounter();
          _log('update available, ${_container.lastDataUpdatedAt}');
          refresh();
        } else {
          _log('update unavailable, ${_container.lastDataUpdatedAt}');
        }
      });
    } catch (e) {
      _log("updateStream error(2) : $e");
    }
  }

  @override
  refresh() {
    if (onRefresh != null) {
      _log("refresh berjalan");
      onRefresh!();
    } else {
      _log("tidak ada refresh");
    }
  }

  Future<void> _presync() async {
    // print("presync counter");
    await _syncCounter();
    // print("presync");

    List<DocumentSnapshot<Map<String, dynamic>>> news =
        await DataCompute().isolate((_) async {
      Query<Map<String, dynamic>> query = _[0];
      List<DocumentSnapshot<Map<String, dynamic>>> news =
          (await query.get()).docs;
      return news;
    }, args: [
      FirestoreUtil().queryBuilder(
        collectionPath,
        sorts: _sorts,
        filters: _filters,
        limit: _size,
      ),
    ]);
    if (news.isNotEmpty) {
      for (DocumentSnapshot<Map<String, dynamic>> doc in news) {
        DataItem element = DataItem.fromMap({
          "id": doc.id,
          "data": doc.data(),
          "name": stateName,
          "parent": collectionPath,
          "createdAt": DateTimeUtils.toDateTime(doc.data()!['createdAt']),
          "updatedAt": DateTimeUtils.toDateTime(doc.data()!['updatedAt']),
          "deletedAt": DateTimeUtils.toDateTime(doc.data()!['deletedAt']),
        });
        try {
          _raw[doc.id] = element;
          _container.ids.add(element.path());
          await _raw[doc.id]!.save({});
        } catch (e) {
          _log("newStream error(1) : $e");
          //
        }
      }
      // print("presync _ end");
      _container.lastDataCreatedAt = DateTime.now();
      _syncContainer();
      refresh();
    }
  }

  Future<void> _sync() async {
    // print("start sync");
    int ac = _container.params['actualCount'];
    int pages = (ac / _size).ceil();
    DocumentSnapshot<Map<String, dynamic>>? ldoc;
    // print("start sync - for");
    for (int i = 0; i < pages; i++) {
      if (ldoc != null) {
        // print("==========${ldoc!.id}");
      }
      List<DocumentSnapshot<Map<String, dynamic>>> news =
          await await DataCompute().isolate((_) async {
        Query<Map<String, dynamic>> query = _[0];
        List<DocumentSnapshot<Map<String, dynamic>>> news =
            (await query.get()).docs;
        // print("=================${news.length}");
        return news;
      }, args: [
        FirestoreUtil().queryBuilder(
          collectionPath,
          sorts: _sorts,
          filters: _filters,
          limit: _size,
          startAfterDocument: ldoc,
        ),
      ]);
      if (news.isNotEmpty) {
        for (DocumentSnapshot<Map<String, dynamic>> doc in news) {
          DataItem element = DataItem.fromMap({
            "id": doc.id,
            "data": doc.data(),
            "name": stateName,
            "parent": collectionPath,
            "createdAt": DateTimeUtils.toDateTime(doc.data()!['createdAt']),
            "updatedAt": DateTimeUtils.toDateTime(doc.data()!['updatedAt']),
            "deletedAt": DateTimeUtils.toDateTime(doc.data()!['deletedAt']),
          });
          try {
            _raw[doc.id] = element;
            _container.ids.add(element.path());
            await _raw[doc.id]!.save({});
          } catch (e) {
            _log("newStream error(1) : $e");
            // print("=================$e");
          }
        }
        ldoc = news.last;
        refresh();
      }
    }
    // print("start sync - end for");
    _container.lastDataCreatedAt = DateTime.now();
    await _syncContainer();
    // print("end sync");
  }

  Future<void> _syncCounter() async {
    int ac = await await DataCompute().isolate((_) async {
      AggregateQuery query = _[0];
      return (await query.get()).count;
    }, args: [
      FirestoreUtil()
          .queryBuilder(collectionPath,
              sorts: _sorts, filters: _filters, isCount: true)
          .count(),
    ]);
    _container.params['actualCount'] = ac;
    _container.params['size'] = _size;
    _syncContainer();
  }

  Future<void> _syncContainer() async {
    _container.ids = _container.ids.toSet().toList();
    _count = _container.ids.length;
    await _saveState();
    refresh();
  }

  /// Find More Efective Data with this function
  @override
  Future<DataQuery> find({
    List<DataFilter>? filters,
    List<DataSort>? sorts,
    DataSearch? search,
    DataPaginate? paginate,
  }) async {
    // _log('findAsync Isolate.spawn');
    Map<String, dynamic> res = {};
    try {
      res = await DataCompute().isolate((args) async {
        Map<String, DataItem> raw = Map<String, DataItem>.from(args[0]);
        List<DataFilter>? filters = args[1];
        List<DataSort>? sorts = args[2];
        DataSearch? search = args[3];
        DataPaginate? paginate = args[4];

        List<DataItem> data = raw.entries.map((entry) => entry.value).toList();

        if (filters != null) {
          data = data.filterData(filters);
        }
        if (sorts != null) {
          data = data.sortData(sorts);
        }
        if (search != null) {
          data = data.searchData(search);
        }
        Map<String, dynamic> result = {};
        result['count'] = data.length;
        if (paginate != null) {
          try {
            result['page'] = paginate.page;
            result['pageSize'] = paginate.size;
            data = data.paginate(paginate);
          } catch (e) {
            //
          }
        }
        result['length'] = data.length;
        result['data'] = data;
        return result;
      }, args: [_raw, filters, sorts, search, paginate]);
    } catch (e, st) {
      _log('findAsync Isolate.spawn $e, $st');
    }
    return DataQuery(
      data: res['data'],
      length: res['length'],
      count: res['count'],
      page: res['page'],
      pageSize: res['pageSize'],
    );
  }

  /// Find More Efective Data with this function
  @override
  Future<DataItem?> get(String id) async {
    // _log('findAsync Isolate.spawn');
    return _raw[id];
  }

  /// Insert and save DataItem
  @override
  Future<DataItem> insertOne(Map<String, dynamic> value, {String? id}) async {
    _container.seq++;
    try {
      if (value['createdAt'] == null) {
        value['createdAt'] = FieldValue.serverTimestamp();
      }
      refresh();
      DocumentReference ref = await FirebaseFirestore.instance
          .collection(collectionPath)
          .add(value);
      DataItem newData = DataItem.create(
        ref.id,
        value: value,
        name: stateName,
        parent: collectionPath,
        seq: _container.seq,
      );
      _raw[newData.id] = newData;
      await newData.save({});
      _container.ids.add(newData.path());
      _container.lastDataCreatedAt = newData.createdAt;
      _count = _container.ids.length;

      await _saveState();
      return newData;
    } catch (e) {
      _log("error disini, $e");
      //
      rethrow;
    }
  }

  @override
  Future<void> insertMany(List<Map<String, dynamic>> values) async {
    for (Map<String, dynamic> value in values) {
      _container.seq++;
      try {
        DocumentReference ref = await FirebaseFirestore.instance
            .collection(collectionPath)
            .add(value);
        DataItem newData = DataItem.create(
          ref.id,
          value: value,
          name: stateName,
          parent: collectionPath,
          seq: _container.seq,
        );
        _raw[newData.id] = newData;
        await newData.save({});
        _container.ids.add(newData.path());
        _container.lastDataCreatedAt = newData.createdAt;
        _count = _container.ids.length;
      } catch (e) {
        //
      }
    }
    try {
      refresh();
      await _saveState();
    } catch (e) {
      _log("error disini");
      //
    }
  }

  /// Update to save DataItem
  @override
  Future<DataItem> updateOne(String id,
      {required Map<String, dynamic> value}) async {
    try {
      _count = _container.ids.length;
    } catch (e, st) {
      _log('findAsync Isolate.spawn $e, $st');
    }

    await _raw[id]!.save(value);
    value['updatedAt'] = FieldValue.serverTimestamp();
    await FirebaseFirestore.instance
        .collection(collectionPath)
        .doc(id)
        .update(value)
        .then((_) {});
    _container.lastDataUpdatedAt = _raw[id]?.updatedAt;
    refresh();
    await _saveState();
    return _raw[id]!;
  }

  /// Deletion DataItem
  @override
  Future<void> removeOne(String id) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      DataItem? d = _raw[id];
      if (d == null) {
        throw "Data with id $id, not found";
      }
      _raw.remove(id);
      _container.ids.remove(id);
      _count = _container.ids.length;
      await prefs.remove(EncryptUtil().encript(d.path()));
      await FirebaseFirestore.instance
          .collection(collectionPath)
          .doc(id)
          .delete();
    } catch (e, st) {
      _log('findAsync Isolate.spawn $e, $st');
    }

    refresh();
    await _saveState();
  }

  @override
  Future<void> removeMany(List<String> ids) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      for (String id in ids) {
        DataItem? d = _raw['id'];
        if (d == null) {
          throw "Data with id $id, not found";
        }
        _raw.remove(id);
        _container.ids.remove(id);
        _count = _container.ids.length;
        await prefs.remove(EncryptUtil().encript(d.path()));
        await FirebaseFirestore.instance
            .collection(collectionPath)
            .doc(id)
            .delete()
            .then((_) {});
      }
    } catch (e, st) {
      _log('findAsync Isolate.spawn $e, $st');
    }

    refresh();
    await _saveState();
  }

  Future<void> _saveState() async {
    _isLoading = true;
    refresh();
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(EncryptUtil().encript(_name),
          EncryptUtil().encript(_container.toJson()));
    } catch (e) {
      //
    }
    _isLoading = false;
    refresh();
  }

  /// Used to load state data from shared preferences
  Future<void> _loadState() async {
    _isLoading = true;
    refresh();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    // print(_container.ids.length);
    for (String id in _container.ids) {
      String? ref = prefs.getString(EncryptUtil().encript(id));
      if (ref == null) {
        // Tidak ada data yang disimpan
      } else {
        DataItem d = DataItem.fromMap(jsonDecode(EncryptUtil().decript(ref)));
        _raw[d.id] = d;
        // _data.add(DataItem.fromMap(jsonDecode(EncryptUtil().decript(ref))));
      }
    }

    _count = _container.ids.length;

    _isLoading = false;
    refresh();
  }

  Future<void> reset() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    // print(_container.ids.length);
    for (String id in _container.ids) {
      DataItem? d = _raw[id];
      if (d == null) {
        throw "Data with id $id, not found";
      }
      _raw.remove(id);
      _container.ids.remove(id);
      _count = _container.ids.length;
      await prefs.remove(EncryptUtil().encript(d.path()));
    }
    await _saveState();
    _isInit = false;
    refresh();
    await _initialize();
  }
}
