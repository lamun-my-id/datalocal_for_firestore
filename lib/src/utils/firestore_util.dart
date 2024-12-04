import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:datalocal/datalocal.dart';
import 'package:flutter/material.dart';

class FirestoreUtil {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Query Builder Firebase Firestore
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
          q = q.where(
            (f.key as DataKey).key,
            isEqualTo: f.isEqualTo,
            isNotEqualTo: f.isNotEqualTo,
            isGreaterThan: f.isGreaterThan,
            isGreaterThanOrEqualTo: f.isGreaterThanOrEqualTo,
            isLessThan: f.isLessThan,
            isLessThanOrEqualTo: f.isLessThanOrEqualTo,
            isNull: f.isNull,
            whereIn: f.whereIn,
            whereNotIn: f.whereNotIn,
            arrayContains: f.arrayContains,
            arrayContainsAny: f.arrayContainsAny,
          );
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

  /// Data Insert Firebase Firestore
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

  /// Data get Firebase Firestore
  Future<DocumentSnapshot<Map<String, dynamic>>> get(
    String collectionPath, {
    required String id,
  }) async {
    DocumentSnapshot<Map<String, dynamic>> ref =
        await _firestore.collection(collectionPath).doc(id).get();
    return ref;
  }

  /// Data Insert and get Firebase Firestore
  Future<DocumentSnapshot<Map<String, dynamic>>> insertAndGet({
    required String collectionPath,
    required Map<String, dynamic> value,
    bool createdAt = true,
  }) async {
    String id =
        await insert(collectionPath, value: value, createdAt: createdAt);
    return await get(collectionPath, id: id);
  }

  /// Data Update Firebase Firestore
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

  /// Data Update and Get Firebase Firestore
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

  /// Data Delete Firebase Firestore
  Future<void> delete(
    String collectionPath, {
    required String id,
  }) async {
    await _firestore.collection(collectionPath).doc(id).delete();
  }
}
