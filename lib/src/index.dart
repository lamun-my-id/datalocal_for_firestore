import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:datalocal/datalocal.dart';
import 'package:datalocal/utils/encrypt.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:datalocal_for_firestore/src/utils/date_time_util.dart';
import 'package:datalocal_for_firestore/src/utils/firestore_util.dart';
import 'package:datalocal_for_firestore/src/extensions/data_item.dart';
import 'package:datalocal_for_firestore/src/extensions/list_data_item.dart';

class DataLocalForFirestore {
  final String _stateName;
  String get stateName => _stateName;

  final String _collectionPath;
  String get collectionPath => _collectionPath;

  List<DataFilter>? _filters;
  List<DataSort>? _sorts;
  Function()? onRefresh;
  final bool _debugMode;

  DataLocalForFirestore(
    String stateName, {
    required String collectionPath,
    // this.filters,
    // this.sorts,
    this.onRefresh,
    bool debugMode = false,
  })  : _collectionPath = collectionPath,
        _debugMode = debugMode,
        _stateName = stateName;

  // Static Func
  /// Used for the first time initialize [DataLocalForFirestore]
  static Future<DataLocalForFirestore> stream(
    String stateName, {
    required String collectionPath,
    List<DataFilter> filters = const [],
    List<DataSort> sorts = const [],
    Function()? onRefresh,
    bool? debugMode,
    int? size,
  }) async {
    DataLocalForFirestore result = DataLocalForFirestore(
      stateName,
      collectionPath: collectionPath,
      // filters: filters,
      // sorts: sorts,
      onRefresh: onRefresh,
      debugMode: debugMode ?? false,
    );
    result._filters = filters;
    result._sorts = sorts;
    if (size != null) result._size = size;

    await result._startStream();
    return result;
  }

  // Local Variable
  bool _isInit = false;
  bool get isInit => _isInit;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  int _count = 0;
  int get count => _count;

  int _actualCount = 0;
  int get actualCount => _actualCount;

  List<DataItem> _data = [];
  List<DataItem> get data => _data;
  late DateTime _lastNewestCheck;
  late DateTime _lastUpdateCheck;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _newStream;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _updateStream;

  // Local Variable Private
  late String _name;
  int _size = 100;

  /// Log DataLocalForFirestore used on debugMode
  _log(dynamic arg) async {
    if (_debugMode) {
      debugPrint(
          '[Debug] DataLocalForFirestore ($stateName): ${arg.toString()}');
    }
  }

  // Function
  /// Used to initialize DataLocalForFirestore
  _startStream() async {
    // ================================
    try {
      _isLoading = true;
      refresh();
      _name = EncryptUtil().encript(
        "DataLocalForFirestore-$stateName",
      );
      try {
        String? res;
        try {
          final SharedPreferences prefs = await SharedPreferences.getInstance();
          res = (prefs.getString(EncryptUtil().encript("$_name-0")));
        } catch (e) {
          _log("error get res");
        }

        if (res == null) {
          _data = [];
          throw "tidak ada state";
        }
        try {
          if (kIsWeb) {
            Map<String, dynamic> value = _jsonToListDataItem([null, res]);
            data.addAll(value['data']);
            _count = data.length;
          } else {
            ReceivePort rPort = ReceivePort();
            await Isolate.spawn(_jsonToListDataItem, [rPort.sendPort, res]);
            Map<String, dynamic> value = await rPort.first;
            data.addAll(value['data']);
            rPort.close();
          }
          refresh();
          _isInit = true;
        } catch (e) {
          _log("initialize error(3) : $e");
          //
        }
        _count = data.length;
        if (count == _size) {
          _loadState().then((value) async {
            // await _syncCountData();
            if (data.length != count) {
              _sync();
            }
          });
        }
      } catch (e) {
        _log("initialize error(2) : $e");
      }
      if (count < 1) {
        await _preSync();
        Future.delayed(const Duration(microseconds: 100)).then((value) async {
          _sync();
        });
      }
      _isInit = true;
      refresh();
      if (count > 0) _syncCount();
      _stream();
    } catch (e) {
      _log("initialize error(1) : $e");
      //
    }
  }

  Future<void> _streamNew() async {
    try {
      List<DataItem> a = await find(
        sorts: [
          DataSort(key: "createdAt", desc: true),
        ],
      );
      if (a.isNotEmpty) {
        _lastNewestCheck = DateTimeUtils.toDateTime(a.first.get('createdAt'))!;
      } else {
        _lastNewestCheck = DateTime(2000);
      }
    } catch (e) {
      //
    }
    try {
      List<DataFilter>? filterUpdate = [];
      if (_filters != null) {
        for (DataFilter filter in _filters!) {
          if (filter.key != "updatedAt" &&
              filter.key != "createdAt" &&
              filter.key != 'deletedAt') {
            filterUpdate.add(filter);
          }
        }
      }
      filterUpdate.add(DataFilter(
        key: "createdAt",
        value: _lastNewestCheck.add(const Duration(seconds: 1)),
        operator: DataFilterOperator.isGreaterThan,
      ));
      _newStream = FirestoreUtil()
          .queryBuilder(
            _collectionPath,
            sorts: [
              DataSort(
                key: "createdAt",
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
              // await Future.delayed(const Duration(seconds: 2));
              if (kIsWeb) {
                _data = _listDataItemAddUpdate([null, data, element])['data'];
              } else {
                _log("ada update");
                ReceivePort rPort = ReceivePort();
                await Isolate.spawn(
                    _listDataItemAddUpdate, [rPort.sendPort, data, element]);
                _data = Map<String, dynamic>.from(await rPort.first)['data'];
                rPort.close();
              }
            } catch (e) {
              _log("newStream error(1) : $e");
            }
          }
          _data = await find(sorts: _sorts);
          refresh();
          _log("ada data baru menyimpan state");
          _lastNewestCheck = DateTime.now();
          await _saveState();
          _count = data.length;
          _newStream?.cancel();
          _streamNew();
        } else {}
      });
    } catch (e) {
      _log("newStream error(2) : $e");
    }
  }

  Future<void> _streamUpdate() async {
    try {
      List<DataItem> a = await find(
        sorts: [
          DataSort(key: "updatedAt", desc: true),
        ],
      );
      if (a.isNotEmpty) {
        _lastUpdateCheck = DateTimeUtils.toDateTime(a.first.get('updatedAt'))!;
      } else {
        _lastUpdateCheck = DateTime.now();
        // print("object gak ada last update");
      }
    } catch (e) {
      //
    }

    try {
      List<DataFilter>? filterUpdate = [];
      if (_filters != null) {
        for (DataFilter filter in _filters!) {
          if (filter.key != "updatedAt" &&
              filter.key != "createdAt" &&
              filter.key != 'deletedAt') {
            filterUpdate.add(filter);
          }
        }
      }
      filterUpdate.add(DataFilter(
        key: "updatedAt",
        value: _lastUpdateCheck.add(const Duration(seconds: 1)),
        operator: DataFilterOperator.isGreaterThan,
      ));
      // _log('start stream $dbName');
      _updateStream = FirestoreUtil()
          .queryBuilder(
            _collectionPath,
            sorts: [
              DataSort(
                key: "updatedAt",
                desc: true,
              ),
            ],
            filters: filterUpdate,
          )
          .snapshots()
          .listen((event) async {
        // _log('listen stream $dbName');
        if (event.docs.isNotEmpty) {
          _log('ada data update ');
          for (DocumentSnapshot<Map<String, dynamic>> doc in event.docs) {
            DataItem element = DataItem.fromMap({
              "id": doc.id,
              "data": doc.data(),
              "createdAt": DateTimeUtils.toDateTime(doc.data()!['createdAt']),
              "updatedAt": DateTimeUtils.toDateTime(doc.data()!['updatedAt']),
              "deletedAt": DateTimeUtils.toDateTime(doc.data()!['deletedAt']),
            });
            // print(element.updatedAt);

            try {
              // await Future.delayed(const Duration(seconds: 2));
              if (kIsWeb) {
                _data = _listDataItemAddUpdate([null, data, element])['data'];
              } else {
                ReceivePort rPort = ReceivePort();
                await Isolate.spawn(
                    _listDataItemAddUpdate, [rPort.sendPort, data, element]);
                _data = Map<String, dynamic>.from(await rPort.first)['data'];
                // print("simpan data");
                // for (DataItem d in _data) {
                //   print(d.updatedAt);
                // }
                rPort.close();
              }
            } catch (e) {
              _log("updateStream error(1) : $e");
            }
          }
          _data = await find(sorts: _sorts);
          refresh();
          _lastUpdateCheck = DateTime.now();
          _log("menyimpan state baru");
          await _saveState();
          _updateStream?.cancel();
          _streamUpdate();
        } else {
          _log(
              'update unavailable $collectionPath ${filterUpdate.length} $_lastUpdateCheck');
        }
      });
    } catch (e) {
      _log("updateStream error(2) : $e");
    }
  }

  Future<void> _stream() async {
    try {
      _streamNew();
    } catch (e) {
      //
    }

    try {
      _streamUpdate();
    } catch (e) {
      // print("error update");
    }
  }

  /// Used to save state data to shared preferences
  Future<void> _saveState() async {
    _isLoading = true;
    refresh();
    int loop = (count / _size).ceil();
    // _log('state akan dibuat ${loop + 1} ($count/$_size)');
    for (int i = 0; i < loop + 1; i++) {
      // _log("start savestate number : ${i + 1}");
      SharedPreferences prefs;
      try {
        prefs = await SharedPreferences.getInstance();
        try {
          if (kIsWeb) {
            String res = _listDataItemToJson(
                [null, data.skip(i * _size).take(_size).toList()]);
            // _log((await rPort.first as String).length);
            prefs.setString(EncryptUtil().encript("$_name-$i"), res);
          } else {
            ReceivePort rPort = ReceivePort();
            // _log("Isolate spawn");
            await Isolate.spawn(_listDataItemToJson,
                [rPort.sendPort, data.skip(i * _size).take(_size).toList()]);
            // _log((await rPort.first as String).length);
            String value = await rPort.first as String;
            prefs.setString(EncryptUtil().encript("$_name-$i"), value);
            rPort.close();
          }
          // _log("Berhasil save data");
        } catch (e) {
          _log("gagal save state : $e");
          //
        }
        // _log("end of savestate number : ${i + 1}");
      } catch (e) {
        _log("pref null");
      }
    }
    _isLoading = false;
    refresh();
  }

  /// Used to load state data from shared preferences
  Future<void> _loadState() async {
    // _log("start loadstate");
    _isLoading = true;
    refresh();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    int i = 0;
    bool lanjut = true;
    List<DataItem> result = [];
    while (lanjut) {
      String? res = (prefs.getString(EncryptUtil().encript("$_name-$i")));
      if (res != null) {
        // _log("start loadstate number: ${i + 1}");
        try {
          if (kIsWeb) {
            Map<String, dynamic> value = _jsonToListDataItem([null, res]);
            result.addAll(value['data']);
          } else {
            ReceivePort rPort = ReceivePort();
            await Isolate.spawn(_jsonToListDataItem, [rPort.sendPort, res]);
            Map<String, dynamic> value = await rPort.first;
            result.addAll(value['data']);
            rPort.close();
          }
          refresh();
          // _log("Berhasil load data");
        } catch (e) {
          //
        }
        i++;
      } else {
        lanjut = false;
      }
    }
    _data = result;
    _count = data.length;
    _data = await find(
        // sorts: sorts
        );
    _isLoading = false;
    refresh();
  }

  /// Used to delete state data from shared preferences
  // Future<void> _deleteState() async {
  //   _isLoading = true;
  //   refresh();
  //   final SharedPreferences prefs = await SharedPreferences.getInstance();
  //   int i = 0;
  //   bool lanjut = true;
  //   List<DataItem> result = [];
  //   while (lanjut) {
  //     String? res = (prefs.getString(EncryptUtil().encript("$_name-$i")));
  //     if (res != null) {
  //       await prefs.remove(EncryptUtil().encript("$_name-$i"));
  //       i++;
  //     } else {
  //       lanjut = false;
  //     }
  //   }
  //   _data = result;
  //   _count = data.length;
  //   _data = await find(
  //       // sorts: sorts
  //       );
  //   _isLoading = false;
  //   refresh();
  // }

  /// Refresh data, launch if onRefresh is include
  refresh() {
    if (onRefresh != null) {
      // _log("refresh berjalan");
      onRefresh!();
    } else {
      // _log("tidak ada refresh");
    }
  }

  void dispose() {}

  /// Find More Efective Data with this function
  Future<List<DataItem>> find({
    List<DataFilter>? filters,
    List<DataSort>? sorts,
    DataSearch? search,
  }) async {
    // _log('findAsync Isolate.spawn');
    Map<String, dynamic> res = {};
    try {
      if (kIsWeb) {
        res = _listDataItemFind([null, data, filters, sorts, search]);
      } else {
        ReceivePort rPort = ReceivePort();
        await Isolate.spawn(
            _listDataItemFind, [rPort.sendPort, data, filters, sorts, search]);
        res = await rPort.first;
        rPort.close();
      }
    } catch (e, st) {
      _log('findAsync Isolate.spawn $e, $st');
    }
    return res['data'];
  }

  /// Insert and save DataItem
  Future<DataItem> insertOne(Map<String, dynamic> value) async {
    DocumentSnapshot<Map<String, dynamic>> d = await FirestoreUtil()
        .insertAndGet(collectionPath: collectionPath, value: value);

    DataItem newData = DataItem.create(
      d.id,
      value: d.data(),
      parent: stateName,
    );
    try {
      data.insert(0, newData);
      refresh();
      find(
              // sorts: sorts
              )
          .then((value) async {
        _data = value;
        _count = data.length;
        refresh();
        _log("start save state");
        await _saveState();
        _log("start save success");
      });
    } catch (e) {
      _log("error disini");
      //
    }
    return newData;
  }

  /// Update to save DataItem
  Future<DataItem> updateOne(String id,
      {required Map<String, dynamic> value}) async {
    try {
      Map<String, dynamic> res = {};
      if (kIsWeb) {
        res = _listDataItemUpdate([null, data, id, value]);
      } else {
        ReceivePort rPort = ReceivePort();
        await Isolate.spawn(
            _listDataItemUpdate, [rPort.sendPort, data, id, value]);
        res = await rPort.first;
        rPort.close();
      }
      _data = res['data'];
      _count = data.length;
    } catch (e, st) {
      _log('findAsync Isolate.spawn $e, $st');
    }

    List<DataItem> d = await find(
      filters: [DataFilter(key: "#id", value: id)],
    );
    if (d.isEmpty) {
      throw "Tidak ada data";
    }
    refresh();
    _saveState();
    return d.first;
  }

  Future<DataItem> updateSyncOne(String id,
      {required Map<String, dynamic> value}) async {
    DataItem d = await updateOne(id, value: value);

    FirestoreUtil().update(collectionPath, id: id, value: value);
    refresh();
    return d;
  }

  Future<DataItem> syncOne(
    String id,
  ) async {
    List<DataItem> d = await find(
      filters: [DataFilter(key: "#id", value: id)],
    );

    FirestoreUtil().update(collectionPath, id: id, value: d.first.data);
    refresh();
    return d.first;
  }

  /// Deletion DataItem
  Future<void> deleteOne(String id) async {
    try {
      Map<String, dynamic> res = {};
      if (kIsWeb) {
        res = _listDataItemDelete([null, data, id]);
      } else {
        ReceivePort rPort = ReceivePort();
        await Isolate.spawn(_listDataItemDelete, [rPort.sendPort, data, id]);
        res = await rPort.first;
        rPort.close();
      }
      _data = res['data'];
      _count = data.length;
      FirestoreUtil().delete(collectionPath, id: id);
    } catch (e, st) {
      _log('findAsync Isolate.spawn $e, $st');
    }

    refresh();
    _saveState();
  }

  Future<void> _preSync() async {
    try {
      if (!isInit) throw "not init yet";

      List<DocumentSnapshot<Map<String, dynamic>>> news = (await FirestoreUtil()
              .queryBuilder(
                _collectionPath,
                sorts: _sorts,
                filters: _filters,
                limit: _size,
              )
              .get())
          .docs;
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
            if (kIsWeb) {
              _data = _listDataItemAddUpdate([null, data, element])['data'];
            } else {
              ReceivePort rPort = ReceivePort();
              await Isolate.spawn(
                  _listDataItemAddUpdate, [rPort.sendPort, data, element]);
              _data = Map<String, dynamic>.from(await rPort.first)['data'];
              rPort.close();
            }
          } catch (e) {
            _log("newStream error(1) : $e");
            //
          }
        }
        _data = await find(sorts: _sorts);
        refresh();
        _saveState();
        _count = data.length;
        _lastNewestCheck = DateTime.now();
      }
    } catch (e) {
      //
    }
  }

  Future<void> _sync() async {
    try {
      if (!isInit) throw "not init yet";
      _isLoading = true;
      refresh();
      _count = (await FirestoreUtil()
                  .queryBuilder(_collectionPath,
                      sorts: _sorts, filters: _filters, isCount: true)
                  .count()
                  .get())
              .count ??
          0;

      List<DocumentSnapshot<Map<String, dynamic>>> news = (await FirestoreUtil()
              .queryBuilder(
                _collectionPath,
                sorts: _sorts,
                filters: _filters,
              )
              .get())
          .docs;
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
            if (kIsWeb) {
              _data = _listDataItemAddUpdate([null, data, element])['data'];
            } else {
              ReceivePort rPort = ReceivePort();
              await Isolate.spawn(
                  _listDataItemAddUpdate, [rPort.sendPort, data, element]);
              _data = Map<String, dynamic>.from(await rPort.first)['data'];
              rPort.close();
            }
          } catch (e) {
            _log("newStream error(1) : $e");
            //
          }
        }
        _data = await find(sorts: _sorts);
        refresh();
        _saveState();
        _count = data.length;
        _lastNewestCheck = DateTime.now();
      }
      _isLoading = false;
      refresh();
    } catch (e) {
      //
    }
  }

  Future<void> _syncCount() async {
    _actualCount = _count = (await FirestoreUtil()
                .queryBuilder(_collectionPath,
                    sorts: _sorts, filters: _filters, isCount: true)
                .count()
                .get())
            .count ??
        0;
    if (_actualCount != count) {
      _sync();
    }
  }

  /// Start from initialize, save state will not deleted
  // Future<void> reboot() async {
  //   await _deleteState();
  //   _data.clear();
  //   await _initialize();
  // }
}

dynamic _listDataItemAddUpdate(List<dynamic> args) {
  // _log('_listDataItemAddUpdate start');
  List<DataItem> result = args[1];
  DataItem newData = args[2];

  int index = result.indexWhere((element) => element.id == newData.id);
  if (index >= 0) {
    result[index] = newData;
  } else {
    result.insert(0, newData);
  }
  if (kIsWeb) {
    return {"data": result, "count": result.length};
  } else {
    SendPort port = args[0];
    Isolate.exit(port, {"data": result, "count": result.length});
  }
}

/// Convert Json to List<DataItem>
dynamic _jsonToListDataItem(List<dynamic> args) {
  List<DataItem> result = [];
  int count = 0;
  try {
    result = List<Map<String, dynamic>>.from(
            jsonDecode(EncryptUtil().decript(args[1])))
        .map((e) => DataItem.fromMap(e))
        .toList();
    count = result.length;
  } catch (e) {
    // print(args[1]);
  }
  if (kIsWeb) {
    return {"data": result, "count": count};
  } else {
    SendPort port = args[0];
    Isolate.exit(port, {"data": result, "count": count});
  }
}

/// Update List DataItem
dynamic _listDataItemUpdate(List<dynamic> args) {
  List<DataItem> result = args[1];
  String id = args[2];
  Map<String, dynamic> update = args[3];

  int i = result.indexWhere((element) => element.id == id);
  if (i >= 0) {
    result[i].update(update);
  }

  if (kIsWeb) {
    return {"data": result, "count": result.length};
  } else {
    SendPort port = args[0];
    Isolate.exit(port, {"data": result, "count": result.length});
  }
}

/// Delete List DataItem
dynamic _listDataItemDelete(List<dynamic> args) {
  List<DataItem> result = args[1];
  String id = args[2];

  int i = result.indexWhere((element) => element.id == id);
  if (i >= 0) {
    result.removeAt(i);
  }

  if (kIsWeb) {
    return {"data": result, "count": result.length};
  } else {
    SendPort port = args[0];
    Isolate.exit(port, {"data": result, "count": result.length});
  }
}

/// Find List DataItem
dynamic _listDataItemFind(List<dynamic> args) {
  // _log('_listDataItemFind start');

  List<DataItem> result = args[1];
  List<DataFilter>? filters = args[2];
  List<DataSort>? sorts = args[3];
  DataSearch? search = args[4];

  if (filters != null) {
    result = result.filterData(filters);
  }
  if (sorts != null) {
    result = result.sortData(sorts);
  }
  if (search != null) {
    result = result.searchData(search);
  }
  // _log(result.length.toString());
  if (kIsWeb) {
    return {"data": result, "count": result.length};
  } else {
    SendPort port = args[0];
    Isolate.exit(port, {"data": result, "count": result.length});
  }
}

/// Convert List<DataItem> to json
dynamic _listDataItemToJson(List<dynamic> args) {
  // _log('_listDataItemToJson start');
  String result = jsonEncode(
    (args[1] as List<DataItem>).map((e) => e.toMap()).toList(),
    toEncodable: (_) {
      if (_ is Timestamp) {
        return DateTime.fromMillisecondsSinceEpoch(_.millisecondsSinceEpoch)
            .toString();
      }
      if (_ is GeoPoint) {
        return {
          "latitude": _.latitude,
          "longitude": _.longitude,
        };
      }
      if (_ is DateTime) {
        return DateTimeUtils.toDateTime(_).toString();
      } else {
        // _log(_.runtimeType.toString());
        return "";
      }
    },
  );
  // _log('${result.length}');
  if (kIsWeb) {
    return EncryptUtil().encript(result);
  } else {
    SendPort port = args[0];
    Isolate.exit(port, EncryptUtil().encript(result));
  }
}
