import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'cashbook_models.dart';

abstract interface class CashbookStore {
  Future<CashbookSnapshot?> load();

  Future<void> save(CashbookSnapshot snapshot);
}

class LocalCashbookStore implements CashbookStore {
  LocalCashbookStore({this._preferences});

  static const storageKey = 'wargakas.cashbook.snapshot.v1';
  SharedPreferences? _preferences;

  Future<SharedPreferences> _getPreferences() async {
    return _preferences ??= await SharedPreferences.getInstance();
  }

  @override
  Future<CashbookSnapshot?> load() async {
    final preferences = await _getPreferences();
    final encoded = preferences.getString(storageKey);
    if (encoded == null) return null;
    return CashbookSnapshot.fromJson(
      Map<String, dynamic>.from(jsonDecode(encoded) as Map),
    );
  }

  @override
  Future<void> save(CashbookSnapshot snapshot) async {
    final preferences = await _getPreferences();
    await preferences.setString(storageKey, jsonEncode(snapshot.toJson()));
  }
}

class MemoryCashbookStore implements CashbookStore {
  MemoryCashbookStore([CashbookSnapshot? initial]) : _snapshot = initial;

  CashbookSnapshot? _snapshot;

  @override
  Future<CashbookSnapshot?> load() async => _snapshot;

  @override
  Future<void> save(CashbookSnapshot snapshot) async {
    _snapshot = snapshot;
  }

  CashbookSnapshot? get snapshot => _snapshot;
}
