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
              switch (data[key].runtimeType) {
                case Timestamp _:
                  value = DateTime.fromMillisecondsSinceEpoch(value[p]);
                  break;
                default:
                  value = value[p];
              }
            }
          }
      }
      return value;
    } catch (e) {
      return null;
    }
  }
}
