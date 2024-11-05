// ignore_for_file: no_wildcard_variable_uses

import 'package:collection/collection.dart';
import 'package:datalocal_for_firestore/datalocal_for_firestore_extension.dart';
import 'package:datalocal_for_firestore/datalocal_for_firestore_query_extension.dart';
// import 'package:datalocal_for_firestore/src/extensions/data_item.dart';
import 'package:datalocal_for_firestore/src/extensions/list.dart';
import 'package:datalocal_for_firestore/datalocal_for_firestore.dart';
import 'package:datalocal_for_firestore/src/extensions/list_data_item_row.dart';
import 'package:datalocal_for_firestore/src/utils/date_time_util.dart';
import 'package:intl/date_symbol_data_local.dart';

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
          if (f.isEqualTo != null) {
            if ((d.get(f.key)) == null) throw "data null";
            if (d.get(f.key) == f.isEqualTo) {
            } else {
              i.add(index);
            }
          }
          if (f.isNotEqualTo != null) {
            if ((d.get(f.key)) == null) throw "data null";
            if (d.get(f.key) != f.isNotEqualTo) {
            } else {
              i.add(index);
            }
          }
          if (f.isGreaterThanOrEqualTo != null) {
            if ((d.get(f.key)) == null) throw "data null";
            if (f.isGreaterThanOrEqualTo is DateTime) {
              if ((DateTimeUtils.toDateTime(d.get(f.key))!)
                  .isAfter(f.isGreaterThanOrEqualTo as DateTime)) {
              } else {
                i.add(index);
              }
            } else {
              if (d.get(f.key) >= f.isGreaterThanOrEqualTo) {
              } else {
                i.add(index);
              }
            }
          }
          if (f.isGreaterThan != null) {
            if ((d.get(f.key)) == null) throw "data null";
            if (f.isGreaterThan is DateTime) {
              if ((DateTimeUtils.toDateTime(d.get(f.key))!)
                  .isAfter(f.isGreaterThan as DateTime)) {
              } else {
                i.add(index);
              }
            } else {
              if (d.get(f.key) > f.isGreaterThan) {
              } else {
                i.add(index);
              }
            }
          }
          if (f.isLessThanOrEqualTo != null) {
            if ((d.get(f.key)) == null) throw "data null";
            if (f.isLessThanOrEqualTo is DateTime) {
              if ((DateTimeUtils.toDateTime(d.get(f.key))!)
                  .isBefore(f.isLessThanOrEqualTo as DateTime)) {
              } else {
                i.add(index);
              }
            } else {
              if (d.get(f.key) <= f.isLessThanOrEqualTo) {
              } else {
                i.add(index);
              }
            }
          }
          if (f.isLessThan != null) {
            if ((d.get(f.key)) == null) throw "data null";
            if (f.isLessThan is DateTime) {
              if ((DateTimeUtils.toDateTime(d.get(f.key))!)
                  .isBefore(f.isLessThan as DateTime)) {
              } else {
                i.add(index);
              }
            } else {
              if (d.get(f.key) < f.isLessThan) {
              } else {
                i.add(index);
              }
            }
          }
          if (f.whereIn != null) {
            if ((d.get(f.key)) == null) throw "data null";
            if ((f.whereIn as List).contains(d.get(f.key))) {
            } else {
              i.add(index);
            }
          }
          if (f.whereNotIn != null) {
            if ((d.get(f.key)) == null) throw "data null";
            if ((f.whereIn as List).contains(d.get(f.key))) {
            } else {
              i.add(index);
            }
          }
          if (f.arrayContains != null) {
            if ((d.get(f.key)) == null) throw "data null";
            if ((d.get(f.key) as List).contains(f.arrayContains)) {
            } else {
              i.add(index);
            }
          }
          if (f.arrayContainsAny != null) {
            if ((d.get(f.key)) == null) throw "data null";
            if ((d.get(f.key) as List).contains(f.arrayContains)) {
            } else {
              i.add(index);
            }
          }
          if (f.isNull != null) {
            if ((d.get(f.key) != null) == (f.isNull as bool)) {
            } else {
              i.add(index);
            }
          }
        } catch (e) {
          i.add(index);
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
        for (DataKey key in parameter.keys!) {
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

  // default page number is 1 and size is 30
  List<DataItem> paginate(DataPaginate value) {
    List<List<DataItem>> data = List<List<DataItem>>.from(chunks(value.size));
    if (value.page < 1) throw "Page ready at 1 to ${data.length}";
    return data[value.page - 1];
  }

  /// Part Extension of [List<DataItem>] to sort data
  List<List<DataItem>> groupData(List<dynamic> parameters) {
    if (parameters.isNotEmpty) {
      List<List<DataItem>> temp = [this];
      for (int i = 0; i < parameters.length; i++) {
        List separates = List.generate(length, (index) {
          return this[index].get(parameters[i]);
        }).toSet().toList();
        separates.sort((a, b) {
          if (a == null || b == null) {
            if (a == null) {
              a = 1;
              b = 1;
              return a.compareTo(0);
            } else {
              a = 0;
              b = 0;
              return a.compareTo(1);
            }
          } else if (a is DateTime || b is DateTime) {
            a = DateTimeUtils.toDateTime(a);
            b = DateTimeUtils.toDateTime(b);
            if (a == null) {
              a = 1;
              b = 1;
              return a.compareTo(0);
            }
            if (b == null) {
              a = 0;
              b = 0;
              return a.compareTo(1);
            }
            return a.compareTo(b);
          } else {
            return a.compareTo(b);
          }
        });
        List<List<DataItem>> store = [];
        for (List<DataItem> dTemp in temp) {
          for (dynamic separate in separates) {
            store.add(dTemp.where((element) {
              return element.get(parameters[i]) == separate;
            }).toList());
          }
        }
        temp = store;
      }
      return temp;
    }
    // Set<String> ids = map((e) => e.id).toSet();
    // retainWhere((x) => ids.remove(x.id));

    return [this];
  }

  /// Find More specific query Data with this function
  Future<List<DataItemRow>> execute(
    List<dynamic> selects, {
    List<DataFilter>? filters,
    List<DataSort>? sorts,
    List<dynamic>? groups,
    int? limit,
  }) async {
    if (limit != null) assert(limit > 0, "Limit harus diatas 0");
    List<DataItem> items = this;
    if (filters != null) items = filterData(filters);
    List<DataItemRow> result = await DataCompute().isolate((_) async {
      await initializeDateFormatting();
      List<DataItem> items = _[0];
      List<dynamic> selects = _[1];
      // List<DataFilter>? filters = _[2];
      // List<DataSort>? sorts = _[3];
      List<dynamic>? groups = _[4];
      List<dynamic> k = groups?.map((key) {
            if (key is String) return DataKey(key);
            if (key is DataKey) return key;
            if (key is DataSelectDate) return key;
            if (key is QueryDistinct) return DataKey(key.key, as: key.as);
            throw "Please fill key with String or DataKey value";
          }).toList() ??
          [];
      List<dynamic> groupQueries = [
        ...selects.whereType<QueryGroup>(),
        ...(groups ?? []).whereType<String>(),
        ...(groups ?? []).whereType<DataSelectDate>(),
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
      // print("dataGroup.length");
      List<List<DataItem>> dataGroup =
          (groups ?? []).isEmpty && groupQueries.isNotEmpty
              ? [items]
              : items.groupData(k);
      // print(dataGroup.length);
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
              } else if (gQ is QueryDistinct) {
                try {
                  temp[gQ.as ?? 'distinctOf${gQ.key}'] = item.get(gQ.key);
                } catch (e) {
                  temp[gQ.as ?? 'distinctOf${gQ.key}'] = item.get(gQ.key) ?? 0;
                }
              } else if (gQ is DataSelectDate) {
                temp[gQ.as ?? "dateFormatOf${gQ.key}"] = item.get(gQ);
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
          result.add(DataItemRow.fromMap(temp));
          if (sorts != null) {
            result = result.sortData(sorts);
          }
        } else {
          if (normQueries.isNotEmpty) {
            // print(dg.length);
            for (DataItem item in dg) {
              Map<String, dynamic> temp = {};
              for (dynamic nm in normQueries) {
                temp[nm.as ?? nm.key] = item.get(nm);
              }
              result.add(DataItemRow.fromMap(temp));
            }
          }
        }
      }
      return result;
    }, args: [items, selects, filters, sorts, groups]);
    if (limit != null && result.length > limit) {
      result = result.slices(limit).toList().first;
    }
    return result;
  }
}
