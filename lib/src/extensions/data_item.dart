// ignore_for_file: no_wildcard_variable_uses

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:datalocal_for_firestore/datalocal_for_firestore.dart';
import 'package:datalocal_for_firestore/src/utils/date_time_util.dart';

extension DataItemExtension on DataItem {
  DataItem setFromDoc(DocumentSnapshot<Map<String, dynamic>> value) {
    return DataItem.fromMap({
      "id": value.id,
      "data": value.data(),
      "createdAt": DateTimeUtils.toDateTime(value.data()!['createdAt']),
      "updatedAt": DateTimeUtils.toDateTime(value.data()!['updatedAt']),
      "deletedAt": DateTimeUtils.toDateTime(value.data()!['deletedAt']),
    });
  }

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
        case "#id":
          value = id;
          break;
        case "#createdAt":
          value = createdAt;
          break;
        case "#updatedAt":
          value = updatedAt;
          break;
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
              } else if (value is String) {
                value = Map<String, dynamic>.from(jsonDecode(value))[p];
              } else {
                value = value[p];
              }
            }
          }
      }
      if (value == null) throw "value null";

      return value;
    } catch (e) {
      if (k.onKeyCatch != null) {
        return get(DataKey(k.onKeyCatch!));
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
          return jsonEncode({
            "latitude": _.latitude,
            "longitude": _.longitude,
          });
        } else {
          return "";
        }
      },
    );
  }

  Future<void> update(Map<String, dynamic> value) async {
    save(value);
    await upSync();
  }

  Future<void> overwrite(Map<String, dynamic> value) async {
    save(value);
    await upSync();
  }

  Future<void> upSync() async {
    await FirebaseFirestore.instance.collection(parent).doc(id).update(data);
  }

  Future<void> downSync() async {
    DocumentSnapshot<Map<String, dynamic>> value =
        await FirebaseFirestore.instance.collection(parent).doc(id).get();
    save(value.data() ?? {});
  }
}
