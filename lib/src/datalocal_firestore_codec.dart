import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Converts Firestore values into DataLocal-compatible Dart values.
///
/// Timestamps become UTC ISO-8601 strings, geographic points become maps,
/// document references become paths, and blobs become base64 strings.
Object? normalizeFirestoreValue(Object? value) {
  if (value is Timestamp) return value.toDate().toUtc().toIso8601String();
  if (value is GeoPoint) {
    return <String, Object?>{
      'latitude': value.latitude,
      'longitude': value.longitude,
    };
  }
  if (value is DocumentReference<Object?>) return value.path;
  if (value is Blob) return base64Encode(value.bytes);
  if (value is Map) {
    return <String, Object?>{
      for (final entry in value.entries)
        entry.key.toString(): normalizeFirestoreValue(entry.value),
    };
  }
  if (value is Iterable) {
    return value.map(normalizeFirestoreValue).toList(growable: false);
  }
  return value;
}

/// Normalizes every field in a Firestore document.
Map<String, Object?> normalizeFirestoreDocument(Map<String, Object?> value) =>
    normalizeFirestoreValue(value)! as Map<String, Object?>;
