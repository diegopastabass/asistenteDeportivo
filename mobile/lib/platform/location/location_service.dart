import '../../core/activity/models.dart';
import '../capability.dart';

/// GPS del teléfono, para rutas de cardio.
abstract interface class LocationService {
  Future<CapabilityStatus> status();

  /// `background`: seguir registrando con la pantalla apagada (requiere el modo
  /// de fondo "location" en Info.plist y el permiso "Siempre").
  Future<CapabilityStatus> requestAccess({bool background = false});

  Future<GeoPoint?> current();

  /// Puntos de la ruta mientras se escucha el stream.
  Stream<GeoPoint> track({double distanceFilterMeters = 5});
}

class UnavailableLocationService implements LocationService {
  const UnavailableLocationService([this._status = CapabilityStatus.notImplemented]);

  final CapabilityStatus _status;

  @override
  Future<CapabilityStatus> status() async => _status;

  @override
  Future<CapabilityStatus> requestAccess({bool background = false}) async => _status;

  @override
  Future<GeoPoint?> current() async => null;

  @override
  Stream<GeoPoint> track({double distanceFilterMeters = 5}) => const Stream.empty();
}
