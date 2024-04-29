import 'package:datalocal_for_firestore/src/extensions/data_item.dart';
import 'package:datalocal/datalocal.dart';
import 'package:datalocal_for_firestore/src/extensions/list.dart';

extension ListDataItem on List<DataItem> {
  /// Part Extension of [List<DataItem>] to sort data
  List<DataItem> sortData(List<DataSort> parameters) {
    if (parameters.isNotEmpty) {
      List<List<DataItem>> temp = [this];
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
          } else {
            return !parameters[i].desc ? a.compareTo(b) : b.compareTo(a);
          }
        });

        List<List<DataItem>> store = [];
        for (List<DataItem> dTemp in temp) {
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
    Set<String> ids = map((e) => e.id).toSet();
    retainWhere((x) => ids.remove(x.id));

    return this;
  }

  /// Part Extension of [List<DataItem>] to filter data
  List<DataItem> filterData(List<DataFilter> parameters) {
    List<DataItem> result = [];
    result.addAll(this);
    List<int> i = [];
    for (int index = 0; index < result.length; index++) {
      DataItem d = result[index];
      for (DataFilter f in parameters) {
        try {
          switch (f.operator) {
            case DataFilterOperator.isEqualTo:
              if (d.get(f.key) == f.value) {
              } else {
                i.add(index);
              }
              break;
            case DataFilterOperator.isNotEqualTo:
              if (d.get(f.key) != f.value) {
              } else {
                i.add(index);
              }
              break;
            case DataFilterOperator.isGreaterThanOrEqualTo:
              if (f.value.runtimeType == DateTime) {
                if ((d.get(f.key) as DateTime).isAfter(f.value as DateTime)) {
                } else {
                  i.add(index);
                }
              } else {
                if (d.get(f.key) >= f.value) {
                } else {
                  i.add(index);
                }
              }
              break;
            case DataFilterOperator.isGreaterThan:
              if (f.value.runtimeType == DateTime) {
                if ((d.get(f.key) as DateTime).isAfter(f.value as DateTime)) {
                } else {
                  i.add(index);
                }
              } else {
                if (d.get(f.key) > f.value) {
                } else {
                  i.add(index);
                }
              }
              break;
            case DataFilterOperator.isLessThanOrEqualTo:
              if (f.value.runtimeType == DateTime) {
                if ((d.get(f.key) as DateTime).isBefore(f.value as DateTime)) {
                } else {
                  i.add(index);
                }
              } else {
                if (d.get(f.key) <= f.value) {
                } else {
                  i.add(index);
                }
              }
              break;
            case DataFilterOperator.isLessThan:
              if (f.value.runtimeType == DateTime) {
                if ((d.get(f.key) as DateTime).isBefore(f.value as DateTime)) {
                } else {
                  i.add(index);
                }
              } else {
                if (d.get(f.key) < f.value) {
                } else {
                  i.add(index);
                }
              }
              break;
            case DataFilterOperator.whereIn:
              if ((f.value as List).contains(d.get(f.key))) {
              } else {
                i.add(index);
              }
              break;
            case DataFilterOperator.whereNotIn:
              if (!(f.value as List).contains(d.get(f.key))) {
              } else {
                i.add(index);
              }
              break;
            case DataFilterOperator.arrayContains:
              if (((d.get(f.key) ?? []) as List).contains(f.value)) {
              } else {
                i.add(index);
              }
              break;
            case DataFilterOperator.arrayContainsAny:
              if (((d.get(f.key) ?? []) as List).containAny(f.value as List)) {
              } else {
                i.add(index);
              }
              break;
            case DataFilterOperator.isNull:
              if (f.value == "false" && d.get(f.key) == null) {
                i.add(index);
              } else if (f.value == "true" && d.get(f.key) != null) {
                i.add(index);
              }
              break;
            default:
              if (d.get(f.key) == f.value) {
              } else {
                i.add(index);
              }
              break;
          }
        } catch (e) {
          // debugPrint("===========asasasas=============${d.get(f.key)}");
          // debugPrint("===========asasasas=============${d.get(f.key)}");
          // result.add(d);
        }
      }
    }
    if (i.isNotEmpty) {
      i.sort((a, b) => b.compareTo(a));
      i = i.toSet().toList();
      for (int index = 0; index < i.length; index++) {
        try {
          result.removeAt(i[index]);
        } catch (e) {
          // debugPrint('data ${i[index]} gagal di remove');
        }
      }
    }
    Set<String> ids = result.map((e) => e.id).toSet();
    result.retainWhere((x) => ids.remove(x.id));

    return result;
  }

  /// Part Extension of [List<DataItem>] to search data
  List<DataItem> searchData(DataSearch parameter) {
    if (parameter.builder == null &&
        (parameter.keys == null && parameter.value == null)) {
      throw "Search exception: silahkan gunakan parameter key dan value atau gunakan builder";
    }
    if (parameter.builder != null &&
        (parameter.keys != null && parameter.value != null)) {
      throw "Search exception: silahkan gunakan salah satu parameter key dan value atau gunakan builder";
    }
    List<DataItem> result = [];
    if (parameter.keys != null && parameter.value != null) {
      for (DataItem data in this) {
        String validator = "";
        for (String key in parameter.keys!) {
          validator += data.get(key) ?? "";
        }
        // final RegExp filterRegExp =
        //     RegExp(validator, caseSensitive: false, unicode: true);
        // if (filterRegExp.hasMatch(parameter.value ?? "")) {
        //   result.add(data);
        // }
        if (validator.toLowerCase().contains(parameter.value!.toLowerCase())) {
          result.add(data);
        }
      }
    }
    // if (parameter.builder != null) {
    //   for (DataItem data in this) {
    //     bool valid = parameter.builder!(data);
    //     if (valid) {
    //       result.add(data);
    //     }
    //   }
    // }
    Set<String> ids = result.map((e) => e.id).toSet();
    result.retainWhere((x) => ids.remove(x.id));
    return result;
  }
}
