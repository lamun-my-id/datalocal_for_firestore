import 'package:cloud_firestore/cloud_firestore.dart';

class DateTimeUtils {
  /// Return diff time
  static Duration differenceTime(dynamic tanggalAwal, dynamic tanggalAkhir) {
    DateTime awal, akhir;

    if (tanggalAwal is DateTime) {
      awal = tanggalAwal;
    } else {
      return const Duration(milliseconds: 0);
    }

    if (tanggalAkhir is DateTime) {
      akhir = tanggalAkhir;
    } else {
      return const Duration(milliseconds: 0);
    }

    Duration duration = akhir.difference(awal);
    return duration;
  }

  /// Return convert string to date
  static DateTime? toDateTime(dynamic tanggal) {
    if (tanggal is String) {
      return DateTime.tryParse(tanggal);
    }
    if (tanggal is DateTime) {
      return tanggal;
    }
    if (tanggal is Timestamp) {
      // debugPrint('timestamp : ${timestampToDateTime(tanggal)}');
      return DateTime.fromMillisecondsSinceEpoch(
          tanggal.millisecondsSinceEpoch);
    }
    return null;
  }
}
