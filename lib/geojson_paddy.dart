// lib/geojson_paddy.dart
// GeoJSON（FeatureCollection）から水田ポリゴンを扱うための最低限のモデル。

import 'package:latlong2/latlong.dart';

class PaddyPolygon {
  final String uuid;
  final int? landType;
  final int? issueYear;
  final LatLng centroid;
  final List<LatLng> outerRing;
  final double minLat;
  final double minLng;
  final double maxLat;
  final double maxLng;

  const PaddyPolygon({
    required this.uuid,
    required this.centroid,
    required this.outerRing,
    required this.minLat,
    required this.minLng,
    required this.maxLat,
    required this.maxLng,
    this.landType,
    this.issueYear,
  });

  /// GeoJSONのFeature（Polygon）から生成。
  /// - 座標は [lng, lat] 形式を想定（EPSG:6668 でも緯度経度がdegreeなのでそのまま描画）
  /// - 穴（inner ring）は今は無視（必要になったら対応）
  factory PaddyPolygon.fromGeoJsonFeature(Map<String, dynamic> feature) {
    final props =
        (feature['properties'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    final geometry =
        (feature['geometry'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};

    final uuid = (props['polygon_uuid'] ?? props['uuid'] ?? '').toString();
    if (uuid.isEmpty) {
      throw FormatException('polygon_uuid が見つからないFeatureがあります');
    }

    final landType = _asIntOrNull(props['land_type']);
    final issueYear = _asIntOrNull(props['issue_year']);

    final coords = geometry['coordinates'];
    if (geometry['type'] != 'Polygon' || coords is! List || coords.isEmpty) {
      throw FormatException('Polygon以外、または coordinates が不正です');
    }

    // outer ring: coordinates[0]
    final outer = coords.first;
    if (outer is! List || outer.isEmpty) {
      throw FormatException('Polygon outer ring が不正です');
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
      throw FormatException('Polygonの点数が不足しています: uuid=$uuid');
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
      uuid: uuid,
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

  static int? _asIntOrNull(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static double? _asDoubleOrNull(dynamic v) {
    if (v is double) return v;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static LatLng _fallbackCentroid(List<LatLng> ring) {
    // 超ざっくり平均（凸/凹を厳密に扱う必要が出たら面積重心に変える）
    double latSum = 0;
    double lngSum = 0;
    for (final p in ring) {
      latSum += p.latitude;
      lngSum += p.longitude;
    }
    return LatLng(latSum / ring.length, lngSum / ring.length);
  }
}
