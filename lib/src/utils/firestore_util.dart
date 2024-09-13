import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:datalocal/datalocal.dart';
import 'package:flutter/material.dart';

class FirestoreUtil {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Query<Map<String, dynamic>> queryBuilder(
    collectionPath, {
    List<DataFilter>? filters,
    List<DataSort>? sorts,
    DocumentSnapshot? startAfterDocument,
    DocumentSnapshot? endBeforeDocument,
    bool isCount = false,
    int? limit,
  }) {
    try {
      Query<Map<String, dynamic>> q = _firestore.collection(collectionPath);
      if (filters != null && filters.isNotEmpty) {
        for (int i = 0; i < filters.length; i++) {
          // log(getVariable(query.filters![i]));
          DataFilter f = filters[i];
          switch (f.operator) {
            case DataFilterOperator.isEqualTo:
              q = q.where(f.key.key, isEqualTo: f.value);
              break;
            case DataFilterOperator.isNotEqualTo:
              q = q.where(f.key.key, isNotEqualTo: f.value);
              break;
            case DataFilterOperator.isGreaterThanOrEqualTo:
              q = q.where(f.key.key, isGreaterThanOrEqualTo: f.value);
              break;
            case DataFilterOperator.isGreaterThan:
              q = q.where(f.key.key, isGreaterThan: f.value);
              break;
            case DataFilterOperator.isLessThanOrEqualTo:
              q = q.where(f.key.key, isLessThanOrEqualTo: f.value);
              break;
            case DataFilterOperator.isLessThan:
              q = q.where(f.key.key, isLessThan: f.value);
              break;
            case DataFilterOperator.whereIn:
              q = q.where(f.key.key, whereIn: f.value);
              break;
            case DataFilterOperator.whereNotIn:
              q = q.where(f.key.key, whereNotIn: f.value);
              break;
            case DataFilterOperator.arrayContains:
              q = q.where(f.key.key, arrayContains: f.value);
              break;
            case DataFilterOperator.arrayContainsAny:
              q = q.where(f.key.key, arrayContainsAny: f.value);
              break;
            case DataFilterOperator.isNull:
              q = q.where(f.key.key, isNull: f.value);
              break;
            default:
              q = q.where(f.key.key, isEqualTo: f.value);
              break;
          }
        }
      }

      if (sorts != null && sorts.isNotEmpty) {
        for (DataSort sort in sorts) {
          q = q.orderBy(
            sort.key.key,
            descending: sort.desc == true,
          );
        }
      }
      if (startAfterDocument != null) {
        q = q.startAfterDocument(startAfterDocument);
      } else {
        // debugPrint('tidak ada start after');
      }
      if (endBeforeDocument != null) {
        q = q.endBeforeDocument(endBeforeDocument);
      } else {
        // debugPrint('tidak ada end before');
      }
      if (limit != null) {
        q = q.limit(limit);
      }
      if (isCount == false) {
        // if (paginations != null) {
        //   q = q.limit(query.paginations!['size']);
        // }
      }

      // debugPrint("${query.dbName} ${q.parameters}");
      return q;
    } catch (e) {
      debugPrint('DatatableDatabase.queryBuilder : $e');
      rethrow;
    }
  }

  Future<String> insert(
    String collectionPath, {
    required Map<String, dynamic> value,
    bool createdAt = true,
  }) async {
    Map<String, dynamic> data = value;
    if (createdAt) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }
    data['updatedAt'] = null;

    DocumentReference<Map<String, dynamic>> ref =
        await _firestore.collection(collectionPath).add(data);
    return ref.id;
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> get(
    String collectionPath, {
    required String id,
  }) async {
    DocumentSnapshot<Map<String, dynamic>> ref =
        await _firestore.collection(collectionPath).doc(id).get();
    return ref;
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> insertAndGet({
    required String collectionPath,
    required Map<String, dynamic> value,
    bool createdAt = true,
  }) async {
    String id =
        await insert(collectionPath, value: value, createdAt: createdAt);
    return await get(collectionPath, id: id);
  }

  Future<void> update(
    String collectionPath, {
    required String id,
    required Map<String, dynamic> value,
    bool updatedAt = true,
  }) async {
    Map<String, dynamic> data = value;
    if (updatedAt) {
      data['updatedAt'] = FieldValue.serverTimestamp();
    }

    await _firestore.collection(collectionPath).doc(id).update(data);
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> updateAndGet(
    String collectionPath, {
    required String id,
    required Map<String, dynamic> value,
    bool updatedAt = true,
  }) async {
    Map<String, dynamic> data = value;
    if (updatedAt) {
      data['updatedAt'] = FieldValue.serverTimestamp();
    }
    await _firestore.collection(collectionPath).doc(id).update(data);
    return await get(collectionPath, id: id);
  }

  Future<void> delete(
    String collectionPath, {
    required String id,
  }) async {
    await _firestore.collection(collectionPath).doc(id).delete();
  }
}
