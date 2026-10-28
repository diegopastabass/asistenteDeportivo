import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/strength/session.dart';

/// Datos que viven solo en el dispositivo: la sesión de fuerza en curso y las
/// preferencias de la interfaz.
class LocalStore {
  LocalStore(this._prefs);

  final SharedPreferences _prefs;

  static String _activeKey(String uid) => 'fuerza-activa:$uid';

  /// La sesión en curso sobrevive a cerrar la app (como en la web con localStorage).
  ActiveWorkout? readActiveWorkout(String uid) {
    final raw = _prefs.getString(_activeKey(uid));
    if (raw == null) return null;
    try {
      return ActiveWorkout.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      return null;
    }
  }

  Future<void> writeActiveWorkout(String uid, ActiveWorkout? w) async {
    if (w == null) {
      await _prefs.remove(_activeKey(uid));
    } else {
      await _prefs.setString(_activeKey(uid), jsonEncode(w.toJson()));
    }
  }

  /// Si ya se mostró la hoja de permisos de Apple Salud (iOS no dice si se aceptó).
  bool get healthRequested => _prefs.getBool('health-requested') ?? false;

  Future<void> markHealthRequested() => _prefs.setBool('health-requested', true);

  /// 'system', 'light' o 'dark'.
  String get themeMode => _prefs.getString('theme') ?? 'system';

  Future<void> setThemeMode(String mode) => _prefs.setString('theme', mode);
}
