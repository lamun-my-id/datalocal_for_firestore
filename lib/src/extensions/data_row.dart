// part of "../models/data_item.dart";

// import 'package:datalocal/datalocal.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:datalocal_for_firestore/datalocal_for_firestore.dart';
import 'package:datalocal_for_firestore/datalocal_for_firestore_query_extension.dart';

extension DataRowExtension on DataItemRow {
  dynamic get(Object key) {
    DataKey k;
    if (key is String) {
      k = DataKey(key);
    } else {
      if ((key is! DataKey)) {
        throw "Please fill key with String or DataKey value";
      }
      k = key;
    }
    try {
      dynamic value = {};
      switch (k.key) {
        default:
          {
            List<String> path = k.key.split(".");
            value = data;

            for (String p in path) {
              if (value[p] is Timestamp) {
                value = DateTime.fromMillisecondsSinceEpoch(
                    value[p].millisecondsSinceEpoch);
              } else if (value[p] is GeoPoint) {
                value = {
                  "latitude": value[p].latitude,
                  "longitude": value[p].longitude,
                };
              }
              value = value[p];
            }
          }
      }
      if (value == null) throw "value null";
      return value;
    } catch (e) {
      if (k.onKeyCatch != null) {
        get(k.onKeyCatch!);
      }
      return null;
    }
  }
}
