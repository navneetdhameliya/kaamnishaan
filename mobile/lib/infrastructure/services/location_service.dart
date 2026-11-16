import 'package:geolocator/geolocator.dart';

import '../shared/app_logger.dart';

typedef LatLng = ({double lat, double lng});

/// Where the phone is, as proof of the visit (photo and job start). Never blocks the work:
/// no permission, no GPS or too slow means no location.
abstract class ILocationService {
  Future<LatLng?> current();
}

class LocationService implements ILocationService {
  @override
  Future<LatLng?> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return null;
      try {
        final p = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 6)),
        );
        return (lat: p.latitude, lng: p.longitude);
      } catch (_) {
        final last = await Geolocator.getLastKnownPosition();
        return last == null ? null : (lat: last.latitude, lng: last.longitude);
      }
    } catch (e) {
      AppLogger.error('Location not available', error: e);
      return null;
    }
  }
}
