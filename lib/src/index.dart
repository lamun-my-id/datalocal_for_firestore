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
          _loadState();
        }
      } catch (e) {
        _log("initialize error(2)#$stateName : $e");
      }
      _isInit = true;
      refresh();

      if (firstTime || _container.ids.isEmpty) {
        await _sync();
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
    print(_container.ids.length);
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
