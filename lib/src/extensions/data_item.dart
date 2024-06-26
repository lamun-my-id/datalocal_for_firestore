import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:datalocal_for_firestore/datalocal_for_firestore.dart';

extension DataItemExtension on DataItem {
  dynamic get(String key) {
    try {
      dynamic value = {};
      switch (key) {
        case "#id":
          value = id;
          break;
        default:
          {
            List<String> path = key.split(".");
            value = data;
            for (String p in path) {
              if (value[p] is Timestamp) {
                value = DateTime.fromMillisecondsSinceEpoch(value[p]);
              }
              if (value[p] is GeoPoint) {
                value = {
                  "latitude": value[p].latitude,
                  "longitude": value[p].longitude,
                };
              } else {
                value = value[p];
              }
              // switch (value[p].runtimeType) {
              //   case Timestamp _:
              //     value = DateTime.fromMillisecondsSinceEpoch(value[p]);
              //     break;
              //   case GeoPoint _:
              //     value = {
              //       "latitude": value[p].latitude,
              //       "longitude": value[p].longitude,
              //     };
              //     break;
              //   default:
              //     value = value[p];
              // }
            }
          }
      }
      return value;
    } catch (e) {
      return null;
    }
  }
}
