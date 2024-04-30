import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:datalocal_for_firestore/datalocal_for_firestore.dart';
import 'package:datalocal_for_firestore/src/utils/date_time_util.dart';

extension DataItemExtension on DataItem {
  dynamic get(DataKey key) {
    try {
      dynamic value = {};
      switch (key.key) {
        case "#id":
          value = id;
          break;
        default:
          {
            List<String> path = key.key.split(".");
            value = data;
            for (String p in path) {
              if (value[p] is Timestamp) {
                value = DateTime.fromMillisecondsSinceEpoch(
                    value[p].millisecondsSinceEpoch);
              }
              if (value[p] is GeoPoint) {
                value = {
                  "latitude": value[p].latitude,
                  "longitude": value[p].longitude,
                };
              } else {
                value = value[p];
              }
            }
          }
      }
      if (value == null) throw "value null";

      return value;
    } catch (e) {
      if (key.onKeyCatch != null) {
        return get(DataKey(key.onKeyCatch!));
      }
      return null;
    }
  }

  String toJson() {
    return jsonEncode(
      toMap(),
      toEncodable: (_) {
        if (_ is DateTime) {
          return DateTimeUtils.toDateTime(_).toString();
        } else if (_ is Timestamp) {
          return DateTime.fromMillisecondsSinceEpoch(_.millisecondsSinceEpoch)
              .toString();
        } else if (_ is GeoPoint) {
          return {
            "latitude": _.latitude,
            "longitude": _.longitude,
          }.toString();
        } else {
          return "";
        }
      },
    );
  }
}
