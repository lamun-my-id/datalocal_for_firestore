// ignore_for_file: no_wildcard_variable_uses

// import 'package:datalocal/datalocal_query_extension.dart';
// import 'package:datalocal_for_firestore/datalocal_for_firestore_query_extension.dart';
import 'package:datalocal_for_firestore/datalocal_for_firestore.dart';
import 'package:datalocal_for_firestore/datalocal_for_firestore_extension.dart';
import 'package:datalocal_for_firestore/datalocal_for_firestore_query_extension.dart';

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
    DataQuery query = await find(
      filters: filters,
      sorts: groups != null ? null : sorts,
    );
    List<DataItemRow> result = await query.data.execute(
      selects,
      filters: filters,
      sorts: sorts,
      groups: groups,
      limit: limit,
    );

    return result;
  }
}

class DataItemRow {
  late Map<String, dynamic> _data;
  Map<String, dynamic> get data => _data;

  /// for local save query result
  static DataItemRow fromMap(Map<String, dynamic> value) {
    DataItemRow row = DataItemRow();
    row._data = value;
    return row;
  }
}
