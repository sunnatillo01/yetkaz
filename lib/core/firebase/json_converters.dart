import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:json_annotation/json_annotation.dart';

/// Firestore [Timestamp] <-> [DateTime].
class TimestampConverter implements JsonConverter<DateTime, Object?> {
  const TimestampConverter();

  @override
  DateTime fromJson(Object? json) => switch (json) {
    final Timestamp t => t.toDate(),
    final String s => DateTime.parse(s),
    final int ms => DateTime.fromMillisecondsSinceEpoch(ms),
    _ => DateTime.fromMillisecondsSinceEpoch(0),
  };

  @override
  Object? toJson(DateTime date) => Timestamp.fromDate(date);
}

/// Like [TimestampConverter] but stores ISO strings — used for Hive cache.
class IsoDateConverter implements JsonConverter<DateTime, Object?> {
  const IsoDateConverter();

  @override
  DateTime fromJson(Object? json) => const TimestampConverter().fromJson(json);

  @override
  Object? toJson(DateTime date) => date.toIso8601String();
}

/// Firestore stores numbers as int or double — normalise to int.
int intFromJson(Object? v) => (v as num?)?.toInt() ?? 0;

/// Normalise to double.
double doubleFromJson(Object? v) => (v as num?)?.toDouble() ?? 0;
