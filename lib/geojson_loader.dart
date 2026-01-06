// lib/geojson_loader.dart

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

import 'geojson_paddy.dart';

bool _isLandType100(Map<String, dynamic> feature) {
  final props = feature['properties'];
  if (props is! Map) return false;

  final v = props['land_type'];

  if (v is num) return v.toInt() == 100;
  if (v is String) return int.tryParse(v) == 100;

  return false;
}

Future<List<PaddyPolygon>> loadPaddyPolygonsFromAsset(String assetPath) async {
  final raw = await rootBundle.loadString(assetPath);
  final jsonMap = json.decode(raw);
  if (jsonMap is! Map<String, dynamic>) {
    throw const FormatException('GeoJSONがMap形式ではありません');
  }
  final features = jsonMap['features'];
  if (features is! List) {
    throw const FormatException('GeoJSONのfeaturesが配列ではありません');
  }

  final out = <PaddyPolygon>[];
  for (final f in features) {
    if (f is Map<String, dynamic>) {
      if (!_isLandType100(f)) continue;

      try {
        out.add(PaddyPolygon.fromGeoJsonFeature(f));
      } catch (_) {
        // 変換できないFeatureはスキップ
      }
    }
  }
  return out;
}

Future<Map<String, Map<String, String>>> loadPolygonIndexFromAsset(
  String assetPath,
) async {
  final raw = await rootBundle.loadString(assetPath);
  final decoded = json.decode(raw);

  if (decoded is! Map) {
    throw const FormatException('polygon_index.json が Map 形式ではありません');
  }

  final out = <String, Map<String, String>>{};
  for (final entry in decoded.entries) {
    final pref = entry.key.toString();
    final citiesAny = entry.value;

    if (citiesAny is! Map) continue;

    out[pref] = citiesAny.map((k, v) => MapEntry(k.toString(), v.toString()));
  }

  if (out.isEmpty) {
    throw const FormatException('polygon_index.json が空、または形式が不正です');
  }

  return out;
}
