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

  late DataContainer _container;

  List<DataItem> _data = [];
  List<DataItem> get data => _data;
  DateTime? _lastNewestCheck;
  DateTime? _lastUpdateCheck;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _newStream;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _updateStream;

  // Local Variable Private
  late String _name;
  int _size = 50;

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
      _name = EncryptUtil().encript(
        "DataLocal-$stateName",
      );
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
            ids: [],
          );
          "tidak ada state";
        } else {
          _container =
              DataContainer.fromMap(jsonDecode(EncryptUtil().decript(res)));
        }
      } catch (e) {
        _log("initialize error(2)#$stateName : $e");
      }
      _isInit = true;
      refresh();
      try {
        if (_container.ids.isNotEmpty) {
          _log("Data item ada mulai loadstate");
          _loadState().then((value) {
            _syncCount();
            _stream();
          });
        } else {
          _log("Data item kosong");
          _preSync().then((value) async {
            await _sync();
            _stream();
          });
        }
      } catch (e) {
        _log("initialize error(2)#$stateName : $e");
      }
    } catch (e) {
      _log("initialize error(1) : $e");
      //
    }
  }

  Future<void> _streamNew() async {
    if (_lastNewestCheck == null) {
      try {
        List<DataItem> a = await find(
          sorts: [
            DataSort(key: "createdAt", desc: true),
          ],
        );
        if (a.isNotEmpty) {
          _lastNewestCheck =
              DateTimeUtils.toDateTime(a.first.get('createdAt'))!;
        } else {
          _lastNewestCheck = DateTime(2000);
        }
      } catch (e) {
        //
      }
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
        value: _lastNewestCheck,
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
          SharedPreferences prefs = await SharedPreferences.getInstance();
          _data.addAll(event.docs.map((e) => DataItem.fromMap({
                "id": e.id,
                "data": e.data(),
                "createdAt": DateTimeUtils.toDateTime(e.data()['createdAt']),
                "updatedAt": DateTimeUtils.toDateTime(e.data()['updatedAt']),
                "deletedAt": DateTimeUtils.toDateTime(e.data()['deletedAt']),
              })));
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
              // if (kIsWeb) {
              //   _data = _listDataItemAddUpdate([null, data, element])['data'];
              // } else {
              //   _log("ada update");
              //   ReceivePort rPort = ReceivePort();
              //   await Isolate.spawn(
              //       _listDataItemAddUpdate, [rPort.sendPort, data, element]);
              //   _data = Map<String, dynamic>.from(await rPort.first)['data'];
              //   rPort.close();
              // }
            } catch (e) {
              _log("newStream error(1) : $e");
            }
            prefs.setString(EncryptUtil().encript(element.id),
                EncryptUtil().encript(element.toJson()));
            _container.ids.add(element.id);
          }
          _data = await find(sorts: _sorts, filters: _filters);
          refresh();
          _log("ada data baru menyimpan state");
          _lastUpdateCheck =
              DateTimeUtils.toDateTime(event.docs.first.data()['createdAt']);
          await _saveState();
          _count = data.length;
          _newStream?.cancel();
          _streamNew();
        } else {
          _log("new Stream unavailable, $_lastNewestCheck");
        }
      });
    } catch (e) {
      _log("newStream error(2) : $e");
    }
  }

  Future<void> _streamUpdate() async {
    if (_lastUpdateCheck == null) {
      try {
        List<DataItem> a = await find(
          sorts: [
            DataSort(key: "updatedAt", desc: true),
          ],
        );
        if (a.isNotEmpty) {
          _log(a.first.id);
          _lastUpdateCheck =
              DateTimeUtils.toDateTime(a.first.get('updatedAt'))!;
        } else {
          _lastUpdateCheck = DateTime.now();
          // _log("object gak ada last update");
        }
      } catch (e) {
        _log(e);
        //
      }
    }

    _log(_lastUpdateCheck);

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
        value: _lastUpdateCheck,
        operator: DataFilterOperator.isGreaterThan,
      ));
      // _log('start stream $collectionPath');
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
        // _log('listen stream $collectionPath');
        if (event.docs.isNotEmpty) {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          _data.addAll(event.docs.map((e) => DataItem.fromMap({
                "id": e.id,
                "data": e.data(),
                "createdAt": DateTimeUtils.toDateTime(e.data()['createdAt']),
                "updatedAt": DateTimeUtils.toDateTime(e.data()['updatedAt']),
                "deletedAt": DateTimeUtils.toDateTime(e.data()['deletedAt']),
              })));
          for (DocumentSnapshot<Map<String, dynamic>> doc in event.docs) {
            DataItem element = DataItem.fromMap({
              "id": doc.id,
              "data": doc.data(),
              "createdAt": DateTimeUtils.toDateTime(doc.data()!['createdAt']),
              "updatedAt": DateTimeUtils.toDateTime(doc.data()!['updatedAt']),
              "deletedAt": DateTimeUtils.toDateTime(doc.data()!['deletedAt']),
            });
            // _log(element.updatedAt);

            try {
              // await Future.delayed(const Duration(seconds: 2));
              // if (kIsWeb) {
              //   _data = _listDataItemAddUpdate([null, data, element])['data'];
              // } else {
              //   ReceivePort rPort = ReceivePort();
              //   await Isolate.spawn(
              //       _listDataItemAddUpdate, [rPort.sendPort, data, element]);
              //   _data = Map<String, dynamic>.from(await rPort.first)['data'];
              //   // _log("simpan data");
              //   // for (DataItem d in _data) {
              //   //   _log(d.updatedAt);
              //   // }
              //   rPort.close();
              // }

              prefs.setString(EncryptUtil().encript(element.id),
                  EncryptUtil().encript(element.toJson()));
              _container.ids.add(element.id);
            } catch (e) {
              _log("updateStream error(1) : $e");
            }
          }
          _data = await find(sorts: _sorts, filters: _filters);
          refresh();
          _lastUpdateCheck =
              DateTimeUtils.toDateTime(event.docs.first.data()['updatedAt']);
          _log("menyimpan state baru");
          await _saveState();
          _updateStream?.cancel();
          _streamUpdate();
        } else {
          _log('update unavailable, $_lastUpdateCheck');
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
      // _log("error update");
    }
  }

  /// Used to save state data to shared preferences
  Future<void> _saveState() async {
    try {
      if (kIsWeb) {
        _container.ids = _listDataItemFindToIds(
            [null, data, _filters, _sorts, null])['data'];
      } else {
        ReceivePort rPort = ReceivePort();
        await Isolate.spawn(_listDataItemFindToIds,
            [rPort.sendPort, data, _filters, _sorts, null]);
        _container.ids = Map<String, dynamic>.from(await rPort.first)['data'];
        rPort.close();
      }

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(EncryptUtil().encript(_name),
          EncryptUtil().encript(_container.toJson()));
      _log('state saved');
    } catch (e) {
      _log("save state error $e");
    }
  }

  /// Used to load state data from shared preferences
  Future<void> _loadState() async {
    _isLoading = true;
    refresh();
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    for (int index = 0; index < _container.ids.length; index++) {
      String id = _container.ids[index];
      String? ref = prefs.getString(EncryptUtil().encript(id));
      if (ref == null) {
        // Tidak ada data yang disimpan
      } else {
        if (kIsWeb) {
          _data = _listDataItemAddUpdate([
            null,
            data,
            DataItem.fromMap(jsonDecode(EncryptUtil().decript(ref)))
          ])['data'];
        } else {
          ReceivePort rPort = ReceivePort();
          await Isolate.spawn(_listDataItemAddUpdate, [
            rPort.sendPort,
            data,
            DataItem.fromMap(jsonDecode(EncryptUtil().decript(ref)))
          ]);
          _data = Map<String, dynamic>.from(await rPort.first)['data'];
          rPort.close();
        }
        if ((index + 1) % _size == 0) {
          _isLoading = false;
          refresh();
        }
        // _data.add(DataItem.fromMap(jsonDecode(EncryptUtil().decript(ref))));
      }
    }
    _count = data.length;
    _log('load state complete');
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
    _count = _container.ids.length;
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
      _data.insert(0, newData);
      refresh();
      find(sorts: _sorts, filters: _filters).then((value) async {
        _data = value;
        _count = data.length;
        refresh();

        SharedPreferences prefs = await SharedPreferences.getInstance();
        prefs.setString(EncryptUtil().encript(newData.id),
            EncryptUtil().encript(newData.toJson()));
        _container.ids.add(newData.id);
        await _saveState();
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
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString(
        EncryptUtil().encript(id), EncryptUtil().encript(d.first.toJson()));
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

    _container.ids.remove(id);

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(EncryptUtil().encript(id));

    refresh();
    _saveState();
  }

  Future<void> _preSync() async {
    _isLoading = true;
    refresh();
    try {
      if (!isInit) throw "not init yet";
      QuerySnapshot<Map<String, dynamic>> query = await FirestoreUtil()
          .queryBuilder(
            _collectionPath,
            sorts: [DataSort(key: "createdAt", desc: true)],
            filters: _filters,
            limit: _size,
          )
          .get();
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<DocumentSnapshot<Map<String, dynamic>>> docs = query.docs;
      if (docs.isNotEmpty) {
        _data.addAll(docs.map((e) => DataItem.fromMap({
              "id": e.id,
              "data": e.data(),
              "createdAt": DateTimeUtils.toDateTime(e.data()!['createdAt']),
              "updatedAt": DateTimeUtils.toDateTime(e.data()!['updatedAt']),
              "deletedAt": DateTimeUtils.toDateTime(e.data()!['deletedAt']),
            })));
        for (DocumentSnapshot<Map<String, dynamic>> doc in docs) {
          DataItem element = DataItem.fromMap({
            "id": doc.id,
            "data": doc.data(),
            "createdAt": DateTimeUtils.toDateTime(doc.data()!['createdAt']),
            "updatedAt": DateTimeUtils.toDateTime(doc.data()!['updatedAt']),
            "deletedAt": DateTimeUtils.toDateTime(doc.data()!['deletedAt']),
          });
          // try {
          //   if (kIsWeb) {
          //     _data = _listDataItemAddUpdate([null, data, element])['data'];
          //   } else {
          //     ReceivePort rPort = ReceivePort();
          //     await Isolate.spawn(
          //         _listDataItemAddUpdate, [rPort.sendPort, data, element]);
          //     _data = Map<String, dynamic>.from(await rPort.first)['data'];

          //     rPort.close();
          //   }
          // } catch (e) {
          //   _log("newStream error(1) : $e");
          //   //
          // }

          prefs.setString(EncryptUtil().encript(element.id),
              EncryptUtil().encript(element.toJson()));
          _container.ids.add(doc.id);
        }
        _data = await find(sorts: _sorts, filters: _filters);
        refresh();
        _saveState();
        _count = data.length;
      } else {}
    } catch (e) {
      //
      _log("gagal presync $e");
    }
    _isLoading = false;
    refresh();
  }

  Future<void> _sync() async {
    _log("mulai sync");
    try {
      if (!isInit) {
        throw "data has not been initialized";
      }

      _log('sync oldest data');
      try {
        DateTime date = DateTime(2000);
        List<DataItem> a = await find(
          sorts: [
            DataSort(key: "createdAt", desc: false),
          ],
        );
        if (a.isNotEmpty) {
          date = DateTimeUtils.toDateTime(a.first.get('createdAt'))!;
        } else {
          date = DateTime(2000);
        }

        List<DataFilter>? filterNews = [];
        if (_filters != null) {
          for (DataFilter filter in _filters!) {
            if (filter.key != "updatedAt" &&
                filter.key != "createdAt" &&
                filter.key != 'deletedAt') {
              filterNews.add(filter);
            }
          }
        }
        filterNews.add(DataFilter(
          key: "createdAt",
          value: date,
          operator: DataFilterOperator.isLessThan,
        ));
        SharedPreferences prefs = await SharedPreferences.getInstance();

        List<DocumentSnapshot<Map<String, dynamic>>> news =
            (await FirestoreUtil()
                    .queryBuilder(
                      collectionPath,
                      sorts: [
                        DataSort(
                          key: "createdAt",
                          desc: true,
                        ),
                      ],
                      filters: filterNews,
                    )
                    .get())
                .docs;
        if (news.isNotEmpty) {
          _data.addAll(news.map((e) => DataItem.fromMap({
                "id": e.id,
                "data": e.data(),
                "createdAt": DateTimeUtils.toDateTime(e.data()!['createdAt']),
                "updatedAt": DateTimeUtils.toDateTime(e.data()!['updatedAt']),
                "deletedAt": DateTimeUtils.toDateTime(e.data()!['deletedAt']),
              })));
          for (DocumentSnapshot<Map<String, dynamic>> doc in news) {
            DataItem element = DataItem.fromMap({
              "id": doc.id,
              "data": doc.data(),
              "createdAt": DateTimeUtils.toDateTime(doc.data()!['createdAt']),
              "updatedAt": DateTimeUtils.toDateTime(doc.data()!['updatedAt']),
              "deletedAt": DateTimeUtils.toDateTime(doc.data()!['deletedAt']),
            });
            // try {
            //   if (kIsWeb) {
            //     _data = _listDataItemAddUpdate([null, data, element])['data'];
            //   } else {
            //     ReceivePort rPort = ReceivePort();
            //     await Isolate.spawn(
            //         _listDataItemAddUpdate, [rPort.sendPort, data, element]);
            //     _data = Map<String, dynamic>.from(await rPort.first)['data'];
            //     rPort.close();
            //   }
            // } catch (e) {
            //   _log("newStream error(1) : $e");
            //   //
            // }

            prefs.setString(EncryptUtil().encript(element.id),
                EncryptUtil().encript(element.toJson()));
            _container.ids.add(doc.id);
          }
          _data = await find(sorts: _sorts, filters: _filters);
          refresh();
          _saveState();
          _count = data.length;
        } else {
          _log("sync, tidak ada data terlama $date");
        }
      } catch (e) {
        //
        _log("sync data terlama gagal");
      }

      _log('sync newest data');
      try {
        DateTime date = DateTime(2000);
        List<DataItem> a = await find(
          sorts: [
            DataSort(key: "createdAt", desc: true),
          ],
        );
        if (a.isNotEmpty) {
          date = DateTimeUtils.toDateTime(a.first.get('createdAt'))!;
        } else {
          date = DateTime(2000);
        }

        List<DataFilter>? filterNews = [];
        if (_filters != null) {
          for (DataFilter filter in _filters!) {
            if (filter.key != "updatedAt" &&
                filter.key != "createdAt" &&
                filter.key != 'deletedAt') {
              filterNews.add(filter);
            }
          }
        }
        filterNews.add(DataFilter(
          key: "createdAt",
          value: date,
          operator: DataFilterOperator.isGreaterThan,
        ));

        List<DocumentSnapshot<Map<String, dynamic>>> news =
            (await FirestoreUtil()
                    .queryBuilder(
                      collectionPath,
                      sorts: [
                        DataSort(
                          key: "createdAt",
                          desc: true,
                        ),
                      ],
                      filters: filterNews,
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

            SharedPreferences prefs = await SharedPreferences.getInstance();
            prefs.setString(EncryptUtil().encript(element.id),
                EncryptUtil().encript(element.toJson()));
            _container.ids.add(doc.id);
          }
          _data = await find(sorts: _sorts, filters: _filters);
          refresh();
          _saveState();
          _count = data.length;
        } else {
          _log("sync, tidak ada data terbaru $date");
        }
      } catch (e) {
        //
        _log("sync data terlama terbaru");
      }
    } catch (e) {
      _log("sync gagal, $e");
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
// dynamic _jsonToListDataItem(List<dynamic> args) {
//   List<DataItem> result = [];
//   int count = 0;
//   try {
//     result = List<Map<String, dynamic>>.from(
//             jsonDecode(EncryptUtil().decript(args[1])))
//         .map((e) => DataItem.fromMap(e))
//         .toList();
//     count = result.length;
//   } catch (e) {
//     // _log(args[1]);
//   }
//   if (kIsWeb) {
//     return {"data": result, "count": count};
//   } else {
//     SendPort port = args[0];
//     Isolate.exit(port, {"data": result, "count": count});
//   }
// }

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

dynamic _listDataItemFindToIds(List<dynamic> args) {
  // _log('_listDataItemFind start');
  List<String> ids = [];
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

  ids = result.map((e) => e.id).toList();

  if (kIsWeb) {
    return {"data": ids, "count": result.length};
  } else {
    SendPort port = args[0];
    Isolate.exit(port, {"data": ids, "count": result.length});
  }
}

/// Convert List<DataItem> to json
// dynamic _listDataItemToJson(List<dynamic> args) {
//   // _log('_listDataItemToJson start');
//   String result = jsonEncode(
//     (args[1] as List<DataItem>).map((e) => e.toMap()).toList(),
//     toEncodable: (_) {
//       if (_ is Timestamp) {
//         return DateTime.fromMillisecondsSinceEpoch(_.millisecondsSinceEpoch)
//             .toString();
//       }
//       if (_ is GeoPoint) {
//         return {
//           "latitude": _.latitude,
//           "longitude": _.longitude,
//         };
//       }
//       if (_ is DateTime) {
//         return DateTimeUtils.toDateTime(_).toString();
//       } else {
//         // _log(_.runtimeType.toString());
//         return "";
//       }
//     },
//   );
//   // _log('${result.length}');
//   if (kIsWeb) {
//     return EncryptUtil().encript(result);
//   } else {
//     SendPort port = args[0];
//     Isolate.exit(port, EncryptUtil().encript(result));
//   }
// }
