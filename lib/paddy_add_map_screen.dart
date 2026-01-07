// lib/paddy_add_map_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math' as math;

import 'geojson_loader.dart';
import 'geojson_paddy.dart';
import 'package:geolocator/geolocator.dart';

class PaddyAddFromMapScreen extends StatefulWidget {
  const PaddyAddFromMapScreen({super.key});

  @override
  State<PaddyAddFromMapScreen> createState() => _PaddyAddFromMapScreenState();
}

class _PaddyAddFromMapScreenState extends State<PaddyAddFromMapScreen> {
  // assets/polygon_index.jsonから読み込み
  Map<String, Map<String, String>> _geoJsonAssets = const {};
  bool _indexReady = false;
  Object? _indexError;

  String _selectedPref = '長野県'; // 初期値
  String _selectedCity = '茅野市'; // 初期値

  String get _selectedAssetPath =>
      _geoJsonAssets[_selectedPref]![_selectedCity]!;

  final MapController _mapController = MapController();
  late Future<List<PaddyPolygon>> _loadFuture;
  bool _pendingMoveToCity = false;

  static const double _polygonZoomThreshold = 16.5;
  static const Duration _recomputeDelay = Duration(milliseconds: 120);

  List<PaddyPolygon> _allPolygons = const [];
  List<PaddyPolygon> _visiblePolygons = const [];

  Timer? _recomputeDebounce;

  final Set<String> _selected = <String>{};

  LatLng? _startCenter;
  bool _locationReady = false;
  static const double _startZoom = 17.0; // 初期ズーム
  static const double _cityMoveMinZoom = 17.0; // 市変更時のズーム最低値
  bool _showPolygons = false;
  double _currentZoom = _startZoom;

  final LayerHitNotifier<String> _polyHitNotifier = ValueNotifier(null);

  bool _mapReady = false;

  final Map<String, PaddyPolygon> _polyByUuid = {};
  final Map<String, double> _areaCacheM2 = {};

  static const double _markerZoomThreshold = 14.5; // これ未満は点すら表示しない
  bool _showMarkers = false;

  double _polygonAreaM2(List<LatLng> points) {
    if (points.length < 3) return 0;

    final pts =
        (points.length >= 2 &&
            points.first.latitude == points.last.latitude &&
            points.first.longitude == points.last.longitude)
        ? points.sublist(0, points.length - 1)
        : points;

    if (pts.length < 3) return 0;

    const R = 6378137.0;
    final lat0 =
        pts.fold<double>(0, (s, p) => s + (p.latitude * math.pi / 180.0)) /
        pts.length;
    final cosLat0 = math.cos(lat0);

    double sum = 0.0;
    for (var i = 0; i < pts.length; i++) {
      final a = pts[i];
      final b = pts[(i + 1) % pts.length];

      final x1 = R * (a.longitude * math.pi / 180.0) * cosLat0;
      final y1 = R * (a.latitude * math.pi / 180.0);
      final x2 = R * (b.longitude * math.pi / 180.0) * cosLat0;
      final y2 = R * (b.latitude * math.pi / 180.0);

      sum += (x1 * y2) - (x2 * y1);
    }
    return (sum.abs() / 2.0);
  }

  LatLngBounds _boundsFromBBoxes(Iterable<PaddyPolygon> polys) {
    var has = false;
    var minLat = double.infinity;
    var minLng = double.infinity;
    var maxLat = -double.infinity;
    var maxLng = -double.infinity;

    for (final p in polys) {
      has = true;
      if (p.minLat < minLat) minLat = p.minLat;
      if (p.minLng < minLng) minLng = p.minLng;
      if (p.maxLat > maxLat) maxLat = p.maxLat;
      if (p.maxLng > maxLng) maxLng = p.maxLng;
    }

    if (!has) {
      return LatLngBounds(const LatLng(0, 0), const LatLng(0, 0));
    }
    return LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));
  }

  void _moveToCityIfPending() {
    if (!_pendingMoveToCity) return;
    if (!_mapReady) return;
    if (_allPolygons.isEmpty) return;

    _pendingMoveToCity = false;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      try {
        final b = _boundsFromBBoxes(_allPolygons);
        if (b.northEast.latitude == 0 && b.northEast.longitude == 0) return;

        _mapController.fitCamera(
          CameraFit.bounds(bounds: b, padding: const EdgeInsets.all(60)),
        );

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final z = _mapController.camera.zoom;
          if (z < _cityMoveMinZoom) {
            _mapController.move(_mapController.camera.center, _cityMoveMinZoom);
          }
          _maybeRecomputeVisible();
        });

        return;
      } catch (_) {
        _mapController.move(_allPolygons.first.centroid, _cityMoveMinZoom);
      }

      _maybeRecomputeVisible();
    });
  }

  double _markerSizeForZoom(double zoom) {
    const double minZoom = 12.0; // これ以下は最小サイズ
    const double maxZoom = _polygonZoomThreshold; // ここに近いほど大きく

    const double minSize = 2.0; // ズームアウト時の最小
    const double maxSize = 16.0; // 閾値付近の最大

    final t = ((zoom - minZoom) / (maxZoom - minZoom)).clamp(0.0, 1.0);
    return minSize + (maxSize - minSize) * t;
  }

  double _areaM2Of(PaddyPolygon p) {
    return _areaCacheM2.putIfAbsent(p.uuid, () => _polygonAreaM2(p.outerRing));
  }

  String _formatArea(double m2) {
    if (m2 >= 10000) return '${(m2 / 10000).toStringAsFixed(2)} ha';
    if (m2 >= 100) {
      return '${(m2 / 100).toStringAsFixed(1)} a（${m2.toStringAsFixed(0)} m²）';
    }
    return '${m2.toStringAsFixed(0)} m²';
  }

  void _maybeRecomputeVisible() {
    if (!mounted) return;
    if (!_locationReady) return;
    if (!_mapReady) return;
    if (_allPolygons.isEmpty) return;

    _scheduleRecomputeVisible();
  }

  @override
  void initState() {
    super.initState();
    _loadFuture = Future.value(const <PaddyPolygon>[]); // 空で初期化

    _initPolygonIndex();
    _initCurrentLocation();
  }

  Future<void> _initPolygonIndex() async {
    try {
      final idx = await loadPolygonIndexFromAsset('assets/polygon_index.json');
      if (!mounted) return;

      // 初期値が無い/変わっても落ちないように補正
      final pref = idx.containsKey(_selectedPref)
          ? _selectedPref
          : idx.keys.first;
      final cities = idx[pref]!;
      final city = cities.containsKey(_selectedCity)
          ? _selectedCity
          : cities.keys.first;

      setState(() {
        _geoJsonAssets = idx;
        _selectedPref = pref;
        _selectedCity = city;

        _indexReady = true;
        _indexError = null;

        // index が揃ってから polygon 読み込み開始
        _loadFuture = loadPaddyPolygonsFromAsset(_selectedAssetPath);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _indexReady = true;
        _indexError = e;
      });
    }
  }

  void _reloadGeoJson({bool moveToCity = false}) {
    if (!_indexReady || _indexError != null) return;

    _allPolygons = const [];
    _visiblePolygons = const [];
    _selected.clear();
    _polyByUuid.clear();
    _areaCacheM2.clear();

    _pendingMoveToCity = moveToCity;

    setState(() {
      _loadFuture = loadPaddyPolygonsFromAsset(_selectedAssetPath);
    });
  }

  void _toggleSelectionByUuid(String uuid) {
    setState(() {
      if (_selected.contains(uuid)) {
        _selected.remove(uuid);
      } else {
        _selected.add(uuid);
      }
    });
  }

  Future<void> _initCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() => _locationReady = true);
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() => _locationReady = true);
        return;
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _maybeRecomputeVisible();
      });

      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        if (!mounted) return;
        setState(() {
          _startCenter = LatLng(last.latitude, last.longitude);
          _locationReady = true;
        });
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );

      if (!mounted) return;
      setState(() {
        _startCenter = LatLng(pos.latitude, pos.longitude);
        _locationReady = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _locationReady = true);
    }
  }

  @override
  void dispose() {
    _recomputeDebounce?.cancel();
    super.dispose();
  }

  void _clearSelection() {
    setState(() => _selected.clear());
  }

  void _submit() {
    if (_selected.isEmpty) return;
    Navigator.pop(context, _selected.toList());
  }

  void _onMapEvent(MapEvent event) {
    _currentZoom = event.camera.zoom;
    _scheduleRecomputeVisible();
  }

  void _scheduleRecomputeVisible() {
    _recomputeDebounce?.cancel();
    _recomputeDebounce = Timer(_recomputeDelay, _recomputeVisible);
  }

  void _recomputeVisible() {
    if (!mounted) return;
    if (!_mapReady) return;
    if (_allPolygons.isEmpty) return;

    final camera = _mapController.camera;
    final zoom = camera.zoom;

    final showPolys = zoom >= _polygonZoomThreshold;
    final showMarkers = !showPolys && zoom >= _markerZoomThreshold;

    // 低ズームは“何も出さない”ので、重い走査をしない
    if (!showPolys && !showMarkers) {
      setState(() {
        _currentZoom = zoom;
        _showPolygons = false;
        _showMarkers = false;
        _visiblePolygons = const [];
      });
      return;
    }

    final b = camera.visibleBounds;
    final sw = b.southWest;
    final ne = b.northEast;

    final latPad = (ne.latitude - sw.latitude) * 0.20;
    final lngPad = (ne.longitude - sw.longitude) * 0.20;

    final minLat = sw.latitude - latPad;
    final maxLat = ne.latitude + latPad;
    final minLng = sw.longitude - lngPad;
    final maxLng = ne.longitude + lngPad;

    final visible = <PaddyPolygon>[];

    if (showPolys) {
      for (final p in _allPolygons) {
        final intersects =
            !(p.maxLat < minLat ||
                p.minLat > maxLat ||
                p.maxLng < minLng ||
                p.minLng > maxLng);
        if (intersects) visible.add(p);
      }
    } else if (showMarkers) {
      for (final p in _allPolygons) {
        final c = p.centroid;
        if (c.latitude >= minLat &&
            c.latitude <= maxLat &&
            c.longitude >= minLng &&
            c.longitude <= maxLng) {
          visible.add(p);
        }
      }
    }

    setState(() {
      _currentZoom = zoom;
      _showPolygons = showPolys;
      _showMarkers = showMarkers;
      _visiblePolygons = visible;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_indexReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_indexError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('地図から追加')),
        body: Center(child: Text('polygon_index.json の読み込みに失敗: $_indexError')),
      );
    }

    return FutureBuilder<List<PaddyPolygon>>(
      future: _loadFuture,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState != ConnectionState.done;
        final error = snapshot.error;
        if (loading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (error != null) {
          return Scaffold(
            appBar: AppBar(title: const Text('地図から水田を追加')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('GeoJSONの読み込みに失敗した: $error'),
              ),
            ),
          );
        }

        final loaded = snapshot.data ?? const <PaddyPolygon>[];
        if (_allPolygons.isEmpty) {
          _allPolygons = loaded;

          _polyByUuid
            ..clear()
            ..addEntries(loaded.map((p) => MapEntry(p.uuid, p)));
          _areaCacheM2.clear();

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _moveToCityIfPending();
            _maybeRecomputeVisible();
          });
        }

        final initial = _allPolygons.isNotEmpty
            ? _allPolygons.first.centroid
            : const LatLng(35.681236, 139.767125);

        if (!_locationReady) {
          return Scaffold(
            appBar: AppBar(title: Text('地図から追加')),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final selectedList = _selected.toList()..sort();
        final totalAreaM2 = selectedList.fold<double>(0.0, (sum, uuid) {
          final p = _polyByUuid[uuid];
          if (p == null) return sum;
          return sum + _areaM2Of(p);
        });

        return Scaffold(
          appBar: AppBar(
            title: const Text('地図から追加'),
            actions: [
              IconButton(
                tooltip: '選択解除',
                onPressed: _selected.isEmpty ? null : _clearSelection,
                icon: const Icon(Icons.backspace),
              ),
              TextButton(
                onPressed: _selected.isEmpty ? null : _submit,
                child: const Text('決定', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),

          body: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _startCenter ?? initial,
                  initialZoom: _startZoom,
                  onMapEvent: _onMapEvent,
                  onMapReady: () {
                    _mapReady = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _moveToCityIfPending();
                      _maybeRecomputeVisible();
                    });
                  },
                  // ↓これをコメントアウトすると回転可能になる
                  interactionOptions: InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://cyberjapandata.gsi.go.jp/xyz/std/{z}/{x}/{y}.png',
                    userAgentPackageName: 'dev.flutter_map.example',
                  ),
                  if (_showPolygons)
                    GestureDetector(
                      behavior: HitTestBehavior.deferToChild,
                      onTap: () {
                        final result = _polyHitNotifier.value;
                        if (result == null || result.hitValues.isEmpty) return;

                        final uuid = result.hitValues.first;
                        _toggleSelectionByUuid(uuid);
                      },
                      child: PolygonLayer<String>(
                        hitNotifier: _polyHitNotifier,
                        polygons: _visiblePolygons.map((p) {
                          final selected = _selected.contains(p.uuid);
                          return Polygon<String>(
                            points: p.outerRing,
                            hitValue: p.uuid,
                            color: selected
                                ? Colors.blue.withAlpha(130)
                                : Colors.green.withAlpha(90),
                            borderColor: selected
                                ? Colors.blueAccent
                                : Colors.green.shade900,
                            borderStrokeWidth: selected ? 3.0 : 1.5,
                          );
                        }).toList(),
                      ),
                    ),

                  if (_showMarkers)
                    MarkerLayer(
                      markers: _visiblePolygons.map((p) {
                        final s = _markerSizeForZoom(_currentZoom);
                        return Marker(
                          point: p.centroid,
                          width: s,
                          height: s,
                          child: Icon(
                            Icons.circle,
                            size: s * 0.8,
                            color: Colors.blueGrey, // 見やすい色に（好みで）
                          ),
                        );
                      }).toList(),
                    ),

                  RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution(
                        '国土地理院地図',
                        onTap: () => launchUrl(
                          Uri.parse(
                            'https://maps.gsi.go.jp/development/ichiran.html',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: SafeArea(
                  child: Card(
                    elevation: 6,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedPref,
                              decoration: const InputDecoration(
                                labelText: '都道府県',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              items: _geoJsonAssets.keys
                                  .map(
                                    (p) => DropdownMenuItem(
                                      value: p,
                                      child: Text(p),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                if (v == null) return;

                                final cities = _geoJsonAssets[v]!.keys.toList();
                                setState(() {
                                  _selectedPref = v;
                                  _selectedCity = cities.first;
                                });

                                // 都道府県変えたら、先頭の市にして読み直し
                                _reloadGeoJson(moveToCity: true);
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedCity,
                              decoration: const InputDecoration(
                                labelText: '市',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              items: (_geoJsonAssets[_selectedPref]!.keys)
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(c),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                if (v == null) return;
                                setState(() => _selectedCity = v);

                                // 市変えたらその市のjsonを読み直し
                                _reloadGeoJson(moveToCity: true);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              if (!_showPolygons)
                Positioned(
                  top: 86,
                  left: 12,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Text(
                        _showMarkers
                            ? 'ズーム ${_polygonZoomThreshold.toStringAsFixed(1)} 以上でポリゴン表示（現在: ${_currentZoom.toStringAsFixed(1)}）'
                            : 'ズーム ${_markerZoomThreshold.toStringAsFixed(1)} 以上で点表示（現在: ${_currentZoom.toStringAsFixed(1)}）',
                      ),
                    ),
                  ),
                ),

              Align(
                alignment: Alignment.bottomCenter,
                child: _SelectionBar(
                  selectedUuids: selectedList,
                  areaTextOf: (uuid) {
                    final p = _polyByUuid[uuid];
                    if (p == null) return '-';
                    return _formatArea(_areaM2Of(p));
                  },
                  totalAreaText: _formatArea(totalAreaM2),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SelectionBar extends StatelessWidget {
  final List<String> selectedUuids;
  final String Function(String uuid) areaTextOf;
  final String totalAreaText;

  const _SelectionBar({
    required this.selectedUuids,
    required this.areaTextOf,
    required this.totalAreaText,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.all(12),
      child: Card(
        elevation: 6,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '選択: ${selectedUuids.length}件',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              if (selectedUuids.isNotEmpty)
                IconButton(
                  tooltip: '選択一覧',
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      showDragHandle: true,
                      builder: (_) {
                        return ListView.separated(
                          itemCount: selectedUuids.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final uuid = selectedUuids[i];
                            return ListTile(
                              leading: const Icon(Icons.crop_square),
                              title: Text(uuid),
                              subtitle: Text('面積: ${areaTextOf(uuid)}'),
                            );
                          },
                        );
                      },
                    );
                  },
                  icon: const Icon(Icons.list),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
