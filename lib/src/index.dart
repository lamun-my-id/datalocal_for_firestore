import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:datalocal/datalocal.dart';
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
    // int size = 100,
  }) async {
    DataLocalForFirestore result = DataLocalForFirestore(
      stateName,
      onRefresh: onRefresh,
      debugMode: debugMode ?? false,
      collectionPath: collectionPath,
    );
    result._sorts = sorts;
    result._filters = filters;
    // result._size = size;
    await result._initialize();
    return result;
  }

  List<DataSort>? _sorts;
  List<DataFilter>? _filters;

  late String _name;

  // late int _size;

  final bool _debugMode;
  late DataContainer _container;

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
  @override
  Map<String, DataItem> get raw => _raw;

  /// Log DataLocal used on debugMode
  _log(dynamic arg) async {
    if (_debugMode) {
      debugPrint('DataLocal (Debug): ${arg.toString()}');
    }
  }

  Future<void> _initialize() async {
    try {
      _name = EncryptUtil().encript(
        "DataLocal-$stateName",
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

      if (firstTime || _container.ids.isEmpty) {
        await _sync();
      } else {
        // print('bukan pertama kalo skip synckon, ${_container.ids.length}');
      }
      _stream();
    } catch (e) {
      _log("initialize error(1) : $e");
      //
    }
  }

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _newStream;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _updateStream;

  Future<void> _stream() async {
    try {
      _streamNews();
    } catch (e) {
      //
    }

    try {
      _streamUpdates();
    } catch (e) {
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
        key: DataKey("createdAt"),
        value: _container.lastDataCreatedAt,
        operator: DataFilterOperator.isGreaterThan,
      ));
      _newStream = FirestoreUtil()
          .queryBuilder(
            collectionPath,
            sorts: [
              DataSort(
                key: DataKey("createdAt"),
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
              "createdAt": DateTimeUtils.toDateTime(doc.data()!['createdAt']),
              "updatedAt": DateTimeUtils.toDateTime(doc.data()!['updatedAt']),
              "deletedAt": DateTimeUtils.toDateTime(doc.data()!['deletedAt']),
            });
            try {
              _raw[doc.id] = element;
              _container.ids.add(doc.id);
              _container.ids = _container.ids.toSet().toList();
              await element.save({});
            } catch (e) {
              _log("newStream error(1) : $e");
              //
            }
          }
          _saveState();
          _count = _container.ids.length;
          _container.lastDataCreatedAt =
              DateTimeUtils.toDateTime(event.docs.first['createdAt']);
          _newStream?.cancel();
          _streamNews();
          refresh();
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
        key: DataKey("updatedAt"),
        value: _container.lastDataUpdatedAt,
        operator: DataFilterOperator.isGreaterThan,
      ));
      // _log('start stream $collectionPath');
      _updateStream = FirestoreUtil()
          .queryBuilder(
            collectionPath,
            sorts: [
              DataSort(
                key: DataKey("updatedAt"),
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
              "createdAt": DateTimeUtils.toDateTime(doc.data()!['createdAt']),
              "updatedAt": DateTimeUtils.toDateTime(doc.data()!['updatedAt']),
              "deletedAt": DateTimeUtils.toDateTime(doc.data()!['deletedAt']),
            });
            try {
              _raw[doc.id] = element;
              await element.save({});
            } catch (e) {
              _log("newStream error(1) : $e");
              //
            }
          }
          _saveState();
          _count = _container.ids.length;
          _container.lastDataUpdatedAt =
              DateTimeUtils.toDateTime(event.docs.first['updatedAt']);
          _updateStream?.cancel();
          _streamUpdates();
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

  Future<void> _sync() async {
    List<DocumentSnapshot<Map<String, dynamic>>> news = (await FirestoreUtil()
            .queryBuilder(
              collectionPath,
              sorts: _sorts,
              filters: _filters,
              // limit: _size,
            )
            .get())
        .docs;
    // print("=================${news.length}");
    if (news.isNotEmpty) {
      for (DocumentSnapshot<Map<String, dynamic>> doc in news) {
        DataItem element = DataItem.fromMap({
          "id": doc.id,
          "data": doc.data(),
          "createdAt": DateTimeUtils.toDateTime(doc.data()!['createdAt']),
          "updatedAt": DateTimeUtils.toDateTime(doc.data()!['updatedAt']),
          "deletedAt": DateTimeUtils.toDateTime(doc.data()!['deletedAt']),
        });
        try {
          _raw[doc.id] = element;
          _container.ids.add(doc.id);
          await element.save({});
        } catch (e) {
          _log("newStream error(1) : $e");
          //
        }
      }
      _saveState();
      _count = _container.ids.length;
      _container.lastDataCreatedAt = DateTime.now();
      refresh();
    }
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
      if (kIsWeb) {
        res = _listDataItemFind([null, _raw, filters, sorts, search, paginate]);
      } else {
        ReceivePort rPort = ReceivePort();
        await Isolate.spawn(_listDataItemFind,
            [rPort.sendPort, _raw, filters, sorts, search, paginate]);
        res = await rPort.first;
        rPort.close();
      }
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

  /// Insert and save DataItem
  @override
  Future<DataItem> insertOne(Map<String, dynamic> value, {String? id}) async {
    _container.seq++;
    DataItem newData = DataItem.create(
      id ??
          EncryptUtil()
              .encript(DateTime.now().toString() + _container.seq.toString()),
      value: value,
      name: stateName,
      parent: "",
      seq: _container.seq,
    );
    try {
      _raw[newData.id] = newData;
      refresh();
      await newData.save({});
      _container.ids.add(newData.path());
      _container.lastDataCreatedAt = newData.createdAt;
      _count = _container.ids.length;
      FirebaseFirestore.instance
          .collection(collectionPath)
          .doc(newData.id)
          .set(value)
          .then((_) {});
      _saveState();
    } catch (e) {
      _log("error disini");
      //
    }
    return newData;
  }

  @override
  Future<void> insertMany(List<Map<String, dynamic>> values) async {
    for (Map<String, dynamic> value in values) {
      _container.seq++;
      DataItem newData = DataItem.create(
        EncryptUtil()
            .encript(DateTime.now().toString() + _container.seq.toString()),
        value: value,
        name: stateName,
        parent: "",
        seq: _container.seq,
      );
      try {
        _raw[newData.id] = newData;
        await newData.save({});
        _container.ids.add(newData.path());
        _container.lastDataCreatedAt = newData.createdAt;
        _count = _container.ids.length;

        FirebaseFirestore.instance
            .collection(collectionPath)
            .doc(newData.id)
            .set(value)
            .then((_) {});
      } catch (e) {
        //
      }
    }
    try {
      refresh();
      _saveState();
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
    FirebaseFirestore.instance
        .collection(collectionPath)
        .doc(id)
        .update(value)
        .then((_) {});
    _container.lastDataUpdatedAt = _raw[id]?.updatedAt;
    refresh();
    _saveState();
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
      FirebaseFirestore.instance
          .collection(collectionPath)
          .doc(id)
          .delete()
          .then((_) {});
    } catch (e, st) {
      _log('findAsync Isolate.spawn $e, $st');
    }

    refresh();
    _saveState();
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
        FirebaseFirestore.instance
            .collection(collectionPath)
            .doc(id)
            .delete()
            .then((_) {});
      }
    } catch (e, st) {
      _log('findAsync Isolate.spawn $e, $st');
    }

    refresh();
    _saveState();
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
}

dynamic _listDataItemFind(List<dynamic> args) {
  Map<String, DataItem> raw = Map<String, DataItem>.from(args[1]);
  List<DataFilter>? filters = args[2];
  List<DataSort>? sorts = args[3];
  DataSearch? search = args[4];
  DataPaginate? paginate = args[5];

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
  if (kIsWeb) {
    return result;
  } else {
    SendPort port = args[0];
    Isolate.exit(port, result);
  }
}
