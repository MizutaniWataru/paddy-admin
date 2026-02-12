import 'package:latlong2/latlong.dart';

class PaddyPolygon {
  final String polyID;
  final bool isInUse;
  final int? landType;
  final int? issueYear;
  final LatLng centroid;
  final List<LatLng> outerRing;
  final double minLat;
  final double minLng;
  final double maxLat;
  final double maxLng;

  const PaddyPolygon({
    required this.polyID,
    this.isInUse = false,
    required this.centroid,
    required this.outerRing,
    required this.minLat,
    required this.minLng,
    required this.maxLat,
    required this.maxLng,
    this.landType,
    this.issueYear,
  });

  factory PaddyPolygon.fromGeoJsonFeature(Map<String, dynamic> feature) {
    final props =
        (feature['properties'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    final geometry =
        (feature['geometry'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};

    final polyID =
        (props['poly_id'] ??
                props['polygon_id'] ??
                props['polygon_uuid'] ??
                props['uuid'] ??
                '')
            .toString();
    if (polyID.isEmpty) {
      throw const FormatException('polygon id is missing');
    }

    final landType = _asIntOrNull(props['land_type']);
    final issueYear = _asIntOrNull(props['issue_year']);

    final coords = geometry['coordinates'];
    if (geometry['type'] != 'Polygon' || coords is! List || coords.isEmpty) {
      throw const FormatException('invalid polygon geometry');
    }

    final outer = coords.first;
    if (outer is! List || outer.isEmpty) {
      throw const FormatException('invalid polygon outer ring');
    }

    final ring = <LatLng>[];
    for (final p in outer) {
      if (p is List && p.length >= 2) {
        final lng = _asDoubleOrNull(p[0]);
        final lat = _asDoubleOrNull(p[1]);
        if (lat != null && lng != null) {
          ring.add(LatLng(lat, lng));
        }
      }
    }

    if (ring.length < 3) {
      throw FormatException('invalid points. poly_id=$polyID');
    }

    final pointLat = _asDoubleOrNull(props['point_lat']);
    final pointLng = _asDoubleOrNull(props['point_lng']);
    final centroid = (pointLat != null && pointLng != null)
        ? LatLng(pointLat, pointLng)
        : _fallbackCentroid(ring);

    var minLat = ring.first.latitude;
    var maxLat = ring.first.latitude;
    var minLng = ring.first.longitude;
    var maxLng = ring.first.longitude;
    for (final p in ring) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    return PaddyPolygon(
      polyID: polyID,
      isInUse: false,
      landType: landType,
      issueYear: issueYear,
      centroid: centroid,
      outerRing: ring,
      minLat: minLat,
      minLng: minLng,
      maxLat: maxLat,
      maxLng: maxLng,
    );
  }

  factory PaddyPolygon.fromApiRow(Map<String, dynamic> row) {
    final polyID = (row['poly_id'] ?? '').toString();
    if (polyID.isEmpty) {
      throw const FormatException('poly_id is missing');
    }
    final isInUse = _asBoolOrFalse(row['in_use']);

    final ring = _extractOuterRing(row['coordinates']);
    if (ring.length < 3) {
      throw FormatException('invalid coordinates. poly_id=$polyID');
    }

    final centroid = _fallbackCentroid(ring);

    var minLat = ring.first.latitude;
    var maxLat = ring.first.latitude;
    var minLng = ring.first.longitude;
    var maxLng = ring.first.longitude;
    for (final p in ring) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    return PaddyPolygon(
      polyID: polyID,
      isInUse: isInUse,
      centroid: centroid,
      outerRing: ring,
      minLat: minLat,
      minLng: minLng,
      maxLat: maxLat,
      maxLng: maxLng,
    );
  }

  static int? _asIntOrNull(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static bool _asBoolOrFalse(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final normalized = v.trim().toLowerCase();
      return normalized == 'true' || normalized == '1' || normalized == 't';
    }
    return false;
  }

  static double? _asDoubleOrNull(dynamic v) {
    if (v is double) return v;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static List<LatLng> _extractOuterRing(dynamic coordinates) {
    dynamic current = coordinates;

    while (current is List && current.isNotEmpty) {
      final first = current.first;
      if (_toLatLngOrNull(first) != null) break;
      if (first is List) {
        current = first;
        continue;
      }
      break;
    }

    if (current is! List) return const <LatLng>[];

    final ring = <LatLng>[];
    for (final point in current) {
      final p = _toLatLngOrNull(point);
      if (p != null) ring.add(p);
    }
    return ring;
  }

  static LatLng? _toLatLngOrNull(dynamic point) {
    if (point is List && point.length >= 2) {
      final lng = _asDoubleOrNull(point[0]);
      final lat = _asDoubleOrNull(point[1]);
      if (lat != null && lng != null) return LatLng(lat, lng);
      return null;
    }

    if (point is Map) {
      final lat = _asDoubleOrNull(point['lat'] ?? point['latitude']);
      final lng = _asDoubleOrNull(
        point['lng'] ?? point['lon'] ?? point['longitude'],
      );
      if (lat != null && lng != null) return LatLng(lat, lng);
      return null;
    }

    return null;
  }

  static LatLng _fallbackCentroid(List<LatLng> ring) {
    double latSum = 0;
    double lngSum = 0;
    for (final p in ring) {
      latSum += p.latitude;
      lngSum += p.longitude;
    }
    return LatLng(latSum / ring.length, lngSum / ring.length);
  }
}
