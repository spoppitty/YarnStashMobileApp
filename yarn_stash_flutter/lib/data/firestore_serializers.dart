import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? dateTimeFromFirestore(Object? value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}

Object? dateTimeToFirestore(DateTime? value) {
  return value == null ? null : Timestamp.fromDate(value);
}

int intFromFirestore(Object? value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  return fallback;
}

List<String> stringListFromFirestore(Object? value) {
  if (value is Iterable) {
    return value.whereType<String>().toList(growable: false);
  }
  return const [];
}
