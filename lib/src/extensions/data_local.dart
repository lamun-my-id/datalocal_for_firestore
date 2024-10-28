// ignore_for_file: no_wildcard_variable_uses

import 'package:datalocal/datalocal_extension.dart';
import 'package:datalocal/datalocal_query_extension.dart';
import 'package:datalocal_for_firestore/datalocal_for_firestore.dart';
import 'package:datalocal_for_firestore/src/extensions/list_data_item_row.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:collection/collection.dart';

extension DataLocalExtensionQuery on DataLocalForFirestore {
  /// Find More specific query Data with this function
  Future<List<DataItemRow>> execute(
    List<dynamic> selects, {
    List<DataFilter>? filters,
    List<DataSort>? sorts,
    List<dynamic>? groups,
    int? limit,
  }) async {
    if (limit != null) assert(limit > 0, "Limit harus diatas 0");
    DataQuery query =
        await find(filters: filters, sorts: groups != null ? null : sorts);
    List<DataItemRow> result = await DataCompute().isolate((_) async {
      await initializeDateFormatting();
      DataQuery query = _[0];
      List<dynamic> selects = _[1];
      // List<DataFilter>? filters = _[2];
      // List<DataSort>? sorts = _[3];
      List<dynamic>? groups = _[4];
      List<dynamic> k = groups?.map((key) {
            if (key is String) return DataKey(key);
            if (key is DataKey) return key;
            if (key is DataSelectDate) return key;
            throw "Please fill key with String or DataKey value";
          }).toList() ??
          [];
      dynamic groupQueries = [
        ...selects.whereType<QueryGroup>(),
        ...(groups ?? []).whereType<String>()
      ];
      List<dynamic> normQueries = selects
          .where((_) => _ is String || _ is DataKey || _ is DataSelectDate)
          .map((_) {
        if (_ is String) {
          return DataKey(_);
        } else {
          return _;
        }
      }).toList();
      List<List<DataItem>> dataGroup =
          // (groups ?? []).isEmpty && groupQueries.isNotEmpty
          //     ? [query.data]
          //     :
          query.data.groupData(k);
      List<DataItemRow> result = [];
      for (List<DataItem> dg in dataGroup) {
        if (groupQueries.isNotEmpty) {
          Map<String, dynamic> temp = {};
          for (dynamic gQ in groupQueries) {
            for (DataItem item in dg) {
              if (gQ is QueryCount) {
                try {
                  temp[gQ.as ?? 'countOf${gQ.key}'] +=
                      item.get(gQ.key) != null ? 1 : 0;
                } catch (e) {
                  temp[gQ.as ?? 'countOf${gQ.key}'] =
                      item.get(gQ.key) != null ? 1 : 0;
                }
              } else if (gQ is QuerySum) {
                try {
                  temp[gQ.as ?? 'sumOf${gQ.key}'] += item.get(gQ.key) ?? 0;
                } catch (e) {
                  temp[gQ.as ?? 'sumOf${gQ.key}'] = item.get(gQ.key) ?? 0;
                }
              } else if (gQ is QueryAverage) {
                try {
                  temp[gQ.as ?? 'averageOf${gQ.key}'] += item.get(gQ.key) ?? 0;
                } catch (e) {
                  temp[gQ.as ?? 'averageOf${gQ.key}'] = item.get(gQ.key) ?? 0;
                }
              } else {
                temp[gQ] = item.get(gQ);
              }
            }
            if (gQ is QueryAverage) {
              if (dg.isEmpty) {
                temp[gQ.as ?? 'averageOf${gQ.key}'] = 0;
              } else {
                temp[gQ.as ?? 'averageOf${gQ.key}'] =
                    temp[gQ.as ?? 'averageOf${gQ.key}'] / dg.length;
              }
            }
            if (normQueries.isNotEmpty) {
              for (DataItem item in dg) {
                for (dynamic nm in normQueries) {
                  temp[nm.key] = item.get(nm);
                }
              }
            }
          }
          result.add(DataItemRow._fromMap(temp));
          if (sorts != null) {
            result = result.sortData(sorts);
          }
        } else {
          if (normQueries.isNotEmpty) {
            for (DataItem item in dg) {
              Map<String, dynamic> temp = {};
              for (DataKey nm in normQueries) {
                temp[nm.key] = item.get(nm);
              }
              result.add(DataItemRow._fromMap(temp));
            }
          }
        }
      }
      return result;
    }, args: [query, selects, filters, sorts, groups]);
    if (limit != null) {
      result = result.slices(limit).toList().first;
    }
    return result;
  }
}

class DataItemRow {
  late Map<String, dynamic> _data;
  Map<String, dynamic> get data => _data;

  static _fromMap(Map<String, dynamic> value) {
    DataItemRow row = DataItemRow();
    row._data = value;
    return row;
  }
}
