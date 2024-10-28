import 'package:datalocal_for_firestore/datalocal_for_firestore.dart';
import 'package:datalocal_for_firestore/datalocal_for_firestore_query_extension.dart';
import 'package:datalocal_for_firestore/src/utils/date_time_util.dart';

extension ListDataItemRow on List<DataItemRow> {
  List<DataItemRow> sortData(List<DataSort> parameters) {
    if (parameters.isNotEmpty) {
      List<List<DataItemRow>> temp = [this];
      for (int i = 0; i < parameters.length; i++) {
        List separates = List.generate(length, (index) {
          return this[index].get(parameters[i].key);
        }).toSet().toList();
        separates.sort((a, b) {
          if (a == null || b == null) {
            if (a == null) {
              a = 1;
              b = 1;
              return !parameters[i].desc ? a.compareTo(0) : b.compareTo(0);
            } else {
              a = 0;
              b = 0;
              return !parameters[i].desc ? a.compareTo(1) : b.compareTo(1);
            }
          } else if (a is DateTime || b is DateTime) {
            a = DateTimeUtils.toDateTime(a);
            b = DateTimeUtils.toDateTime(b);
            if (a == null) {
              a = 1;
              b = 1;
              return !parameters[i].desc ? a.compareTo(0) : b.compareTo(0);
            }
            if (b == null) {
              a = 0;
              b = 0;
              return !parameters[i].desc ? a.compareTo(1) : b.compareTo(1);
            }
            return !parameters[i].desc ? a.compareTo(b) : b.compareTo(a);
          } else {
            return !parameters[i].desc ? a.compareTo(b) : b.compareTo(a);
          }
        });

        List<List<DataItemRow>> store = [];
        for (List<DataItemRow> dTemp in temp) {
          for (dynamic separate in separates) {
            store.add(dTemp.where((element) {
              return element.get(parameters[i].key) == separate;
            }).toList());
          }
        }
        temp = store;
      }
      return temp.expand((element) => element).toList();
    }
    return this;
  }
}
