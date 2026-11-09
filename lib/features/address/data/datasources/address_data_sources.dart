import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:food_delivery/core/entities/coordinates.dart';
import 'package:food_delivery/core/error/exceptions.dart';
import 'package:food_delivery/core/error/failures.dart';
import 'package:food_delivery/core/storage/hive_boxes.dart';
import 'package:food_delivery/features/address/data/models/address_model.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class AddressRemoteDataSource {
  AddressRemoteDataSource(this._firestore, this._auth);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _collection {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const AuthException(AuthErrorCode.sessionExpired);
    return _firestore.collection('users').doc(uid).collection('addresses');
  }

  Stream<List<AddressModel>> watch() => _collection.snapshots().map(
    (s) => s.docs.map((d) => AddressModel.fromJson({...d.data(), 'id': d.id})).toList(),
  );

  Future<AddressModel> save(AddressModel model) async {
    if (model.id == null) {
      final ref = await _collection.add(model.toFirestore());
      return model.copyWith(id: ref.id);
    }
    await _collection.doc(model.id).set(model.toFirestore());
    return model;
  }

  Future<void> delete(String id) => _collection.doc(id).delete();
}

@lazySingleton
class AddressLocalDataSource {
  AddressLocalDataSource(@Named(HiveBoxes.address) this._box);

  final Box<String> _box;
  static const _currentKey = 'current';

  AddressModel? readCurrent() {
    final raw = _box.get(_currentKey);
    if (raw == null) return null;
    try {
      return AddressModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      return null;
    }
  }

  Future<void> writeCurrent(AddressModel model) =>
      _box.put(_currentKey, jsonEncode(model.toJson()));
}

/// Wrapper around geolocator / geocoding so it can be mocked in tests.
@lazySingleton
class LocationDataSource {
  Future<Coordinates> currentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException(LocationErrorCode.serviceDisabled);
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    switch (permission) {
      case LocationPermission.denied:
        throw const LocationException(LocationErrorCode.denied);
      case LocationPermission.deniedForever:
        throw const LocationException(LocationErrorCode.deniedForever);
      case LocationPermission.whileInUse:
      case LocationPermission.always:
      case LocationPermission.unableToDetermine:
        break;
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
    return Coordinates(lat: position.latitude, lng: position.longitude);
  }

  Future<String> reverseGeocode(Coordinates p, {String? languageCode}) async {
    final geocoding = Geocoding(locale: languageCode == null ? null : Locale(languageCode));
    final placemarks = await geocoding.placemarkFromCoordinates(p.lat, p.lng);
    if (placemarks.isEmpty) throw const NotFoundException();
    final m = placemarks.first;
    final parts = <String?>[
      m.street ?? m.thoroughfare,
      if (m.subThoroughfare?.isNotEmpty ?? false) m.subThoroughfare,
      m.subLocality,
      m.locality,
    ].whereType<String>().where((s) => s.trim().isNotEmpty).toSet();
    return parts.join(', ');
  }

  Future<void> openAppSettings() => Geolocator.openAppSettings();

  Future<void> openLocationSettings() => Geolocator.openLocationSettings();
}
