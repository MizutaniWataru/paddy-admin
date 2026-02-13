import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'constants.dart';
import 'geojson_paddy.dart';

class PaddyAddFromMapScreen extends StatefulWidget {
  const PaddyAddFromMapScreen({super.key});

  @override
  State<PaddyAddFromMapScreen> createState() => _PaddyAddFromMapScreenState();
}

class _PaddyAddFromMapScreenState extends State<PaddyAddFromMapScreen> {
  final MapController _mapController = MapController();
  final LayerHitNotifier<String> _polyHitNotifier = ValueNotifier(null);

  late Future<List<PaddyPolygon>> _loadFuture;
  bool _isReloading = false;

  static const double _startZoom = 17.0;
  static const double _polygonZoomThreshold = 16.5;
  static const double _markerZoomThreshold = 14.5;
  static const Duration _recomputeDelay = Duration(milliseconds: 120);
  static final RegExp _codePattern = RegExp(r'^\d{6}$');
  static const String _defaultPrefectureCode = '20';
  static const String _defaultLocalGovernmentCode = '202142';

  List<PaddyPolygon> _allPolygons = const [];
  List<PaddyPolygon> _visiblePolygons = const [];
  List<_LocalGovernmentOption> _localGovernmentOptions = const [];
  final Set<String> _selectedPolyIDs = <String>{};
  final Map<String, PaddyPolygon> _polyByID = {};
  final Map<String, double> _areaCacheM2 = {};
  String _selectedPrefectureCode = _defaultPrefectureCode;
  String _selectedLocalGovernmentCode = _defaultLocalGovernmentCode;

  Timer? _recomputeDebounce;
  LatLng? _startCenter;
  bool _locationReady = false;
  bool _mapReady = false;
  bool _showPolygons = false;
  bool _showMarkers = false;
  double _currentZoom = _startZoom;

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadInitialData();
    _initCurrentLocation();
  }

  @override
  void dispose() {
    _recomputeDebounce?.cancel();
    _polyHitNotifier.dispose();
    super.dispose();
  }

  Future<List<PaddyPolygon>> _loadPolygonsFromApi({
    String localGovernmentCode = '',
    String prefectureCode = '',
  }) async {
    final query = <String, String>{};
    final normalizedLocalCode = localGovernmentCode.trim();
    final normalizedPrefCode = prefectureCode.trim();
    if (normalizedLocalCode.isNotEmpty) {
      query['local_government_code'] = normalizedLocalCode;
    } else if (normalizedPrefCode.isNotEmpty) {
      query['prefecture_code'] = normalizedPrefCode;
    }

    final uri = Uri.parse(
      '$kPaddyDbBaseUrl/api/polygons',
    ).replace(queryParameters: query.isEmpty ? null : query);
    final res = await http.get(uri);

    if (res.statusCode != 200) {
      throw Exception('ポリゴン取得に失敗しました: ${res.statusCode}');
    }

    final decoded = json.decode(utf8.decode(res.bodyBytes));
    if (decoded is! List) {
      throw const FormatException('ポリゴンAPIのレスポンス形式が不正です');
    }

    final out = <PaddyPolygon>[];
    for (final row in decoded) {
      Map<String, dynamic>? m;
      if (row is Map<String, dynamic>) {
        m = row;
      } else if (row is Map) {
        m = row.cast<String, dynamic>();
      }
      if (m == null) continue;

      try {
        out.add(PaddyPolygon.fromApiRow(m));
      } catch (_) {
        continue;
      }
    }
    return out;
  }

  Future<List<_LocalGovernmentOption>> _loadLocalGovernmentsFromApi() async {
    final uri = Uri.parse('$kPaddyDbBaseUrl/api/polygons/local-governments');
    final res = await http.get(uri);

    if (res.statusCode != 200) {
      throw Exception('自治体一覧の取得に失敗しました: ${res.statusCode}');
    }

    final decoded = json.decode(utf8.decode(res.bodyBytes));
    if (decoded is! List) {
      throw const FormatException('自治体一覧APIのレスポンス形式が不正です');
    }

    final out = <_LocalGovernmentOption>[];
    for (final row in decoded) {
      Map<String, dynamic>? m;
      if (row is Map<String, dynamic>) {
        m = row;
      } else if (row is Map) {
        m = row.cast<String, dynamic>();
      }
      if (m == null) continue;

      final option = _LocalGovernmentOption.fromApiRow(m);
      if (option == null) continue;
      out.add(option);
    }

    out.sort((a, b) {
      final pref = a.prefectureCode.compareTo(b.prefectureCode);
      if (pref != 0) return pref;
      final city = a.municipalityName.compareTo(b.municipalityName);
      if (city != 0) return city;
      return a.code.compareTo(b.code);
    });
    return out;
  }

  void _applyDefaultSelectionFromOptions() {
    if (_localGovernmentOptions.isEmpty) {
      _selectedPrefectureCode = '';
      _selectedLocalGovernmentCode = '';
      return;
    }

    final hasCurrentCity = _localGovernmentOptions.any(
      (o) => o.code == _selectedLocalGovernmentCode,
    );
    if (hasCurrentCity) {
      final selected = _localGovernmentOptions.firstWhere(
        (o) => o.code == _selectedLocalGovernmentCode,
      );
      _selectedPrefectureCode = selected.prefectureCode;
      return;
    }

    final hasDefaultCity = _localGovernmentOptions.any(
      (o) => o.code == _defaultLocalGovernmentCode,
    );
    if (hasDefaultCity) {
      _selectedLocalGovernmentCode = _defaultLocalGovernmentCode;
      _selectedPrefectureCode = _defaultPrefectureCode;
      return;
    }

    final first = _localGovernmentOptions.first;
    _selectedLocalGovernmentCode = first.code;
    _selectedPrefectureCode = first.prefectureCode;
  }

  Future<List<PaddyPolygon>> _loadInitialData() async {
    _localGovernmentOptions = await _loadLocalGovernmentsFromApi();
    _applyDefaultSelectionFromOptions();
    if (_selectedLocalGovernmentCode.isEmpty &&
        _selectedPrefectureCode.isEmpty) {
      return const <PaddyPolygon>[];
    }
    return _loadPolygonsFromApi(
      localGovernmentCode: _selectedLocalGovernmentCode,
      prefectureCode: _selectedPrefectureCode,
    );
  }

  Future<void> _reloadPolygons() async {
    _allPolygons = const [];
    _visiblePolygons = const [];
    _selectedPolyIDs.clear();
    _polyByID.clear();
    _areaCacheM2.clear();

    setState(() {
      _isReloading = true;
      _loadFuture = _loadInitialData();
    });

    try {
      await _loadFuture;
    } finally {
      if (mounted) {
        setState(() {
          _isReloading = false;
        });
      }
    }
  }

  Future<void> _reloadPolygonsForCurrentFilter() async {
    if (_isReloading) return;

    _allPolygons = const [];
    _visiblePolygons = const [];
    _selectedPolyIDs.clear();
    _polyByID.clear();
    _areaCacheM2.clear();

    setState(() {
      _isReloading = true;
      _loadFuture = _loadPolygonsFromApi(
        localGovernmentCode: _selectedLocalGovernmentCode,
        prefectureCode: _selectedPrefectureCode,
      );
    });

    try {
      await _loadFuture;
    } finally {
      if (mounted) {
        setState(() {
          _isReloading = false;
        });
      }
    }
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

  double _polygonAreaM2(List<LatLng> points) {
    if (points.length < 3) return 0;

    final pts =
        (points.length >= 2 &&
            points.first.latitude == points.last.latitude &&
            points.first.longitude == points.last.longitude)
        ? points.sublist(0, points.length - 1)
        : points;

    if (pts.length < 3) return 0;

    const r = 6378137.0;
    final lat0 =
        pts.fold<double>(0, (s, p) => s + (p.latitude * math.pi / 180.0)) /
        pts.length;
    final cosLat0 = math.cos(lat0);

    double sum = 0.0;
    for (var i = 0; i < pts.length; i++) {
      final a = pts[i];
      final b = pts[(i + 1) % pts.length];

      final x1 = r * (a.longitude * math.pi / 180.0) * cosLat0;
      final y1 = r * (a.latitude * math.pi / 180.0);
      final x2 = r * (b.longitude * math.pi / 180.0) * cosLat0;
      final y2 = r * (b.latitude * math.pi / 180.0);

      sum += (x1 * y2) - (x2 * y1);
    }
    return sum.abs() / 2.0;
  }

  double _areaM2Of(PaddyPolygon p) {
    return _areaCacheM2.putIfAbsent(
      p.polyID,
      () => _polygonAreaM2(p.outerRing),
    );
  }

  String _formatArea(double m2) {
    if (m2 >= 10000) return '${(m2 / 10000).toStringAsFixed(2)} ha';
    if (m2 >= 100) return '${(m2 / 100).toStringAsFixed(1)} a';
    return '${m2.toStringAsFixed(0)} m²';
  }

  double _markerSizeForZoom(double zoom) {
    const minZoom = 12.0;
    const maxZoom = _polygonZoomThreshold;
    const minSize = 2.0;
    const maxSize = 16.0;
    final t = ((zoom - minZoom) / (maxZoom - minZoom)).clamp(0.0, 1.0);
    return minSize + (maxSize - minSize) * t;
  }

  _LocalGovernmentOption? _localGovernmentByCode(String code) {
    for (final option in _localGovernmentOptions) {
      if (option.code == code) return option;
    }
    return null;
  }

  List<_PrefectureOption> get _prefectureOptions {
    final map = <String, String>{};
    for (final option in _localGovernmentOptions) {
      map.putIfAbsent(option.prefectureCode, () => option.prefectureName);
    }

    final options =
        map.entries
            .map((e) => _PrefectureOption(code: e.key, name: e.value))
            .toList()
          ..sort((a, b) => a.code.compareTo(b.code));
    return options;
  }

  List<_LocalGovernmentOption> get _municipalityOptions {
    if (_selectedPrefectureCode.isEmpty) {
      return _localGovernmentOptions;
    }
    return _localGovernmentOptions
        .where((o) => o.prefectureCode == _selectedPrefectureCode)
        .toList();
  }

  bool get _needsMunicipalitySelection =>
      _selectedLocalGovernmentCode.isEmpty && _municipalityOptions.isNotEmpty;

  bool _matchesCurrentFilter(PaddyPolygon polygon) {
    if (_selectedLocalGovernmentCode.isEmpty) {
      return false;
    }
    final code = polygon.localGovernmentCode.trim();
    if (_selectedPrefectureCode.isNotEmpty &&
        !code.startsWith(_selectedPrefectureCode)) {
      return false;
    }
    if (_selectedLocalGovernmentCode.isNotEmpty &&
        code != _selectedLocalGovernmentCode) {
      return false;
    }
    return true;
  }

  int get _filteredPolygonCount {
    var count = 0;
    for (final polygon in _allPolygons) {
      if (_matchesCurrentFilter(polygon)) {
        count++;
      }
    }
    return count;
  }

  void _onPrefectureChanged(String? newValue) {
    final nextPrefectureCode = newValue ?? '';
    setState(() {
      _selectedPrefectureCode = nextPrefectureCode;
      _selectedLocalGovernmentCode = '';
      _selectedPolyIDs.clear();
      _visiblePolygons = const [];
    });
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('市町村を選択してください')));
  }

  void _onMunicipalityChanged(String? newValue) {
    final nextValue = newValue ?? '';
    if (nextValue.isEmpty) return;
    final selected = _localGovernmentByCode(nextValue);
    setState(() {
      _selectedLocalGovernmentCode = nextValue;
      if (selected != null) {
        _selectedPrefectureCode = selected.prefectureCode;
      }
    });
    _reloadPolygonsForCurrentFilter();
  }

  void _toggleSelectionByID(String polyID) {
    final polygon = _polyByID[polyID];
    if (polygon == null) return;
    if (polygon.isInUse) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('すでに使用中の圃場です')));
      return;
    }

    setState(() {
      if (_selectedPolyIDs.contains(polyID)) {
        _selectedPolyIDs.remove(polyID);
      } else {
        _selectedPolyIDs.add(polyID);
      }
    });
  }

  void _clearSelection() {
    setState(() => _selectedPolyIDs.clear());
  }

  void _submit() {
    if (_selectedPolyIDs.isEmpty) return;
    Navigator.pop(context, _selectedPolyIDs.toList());
  }

  void _onMapEvent(MapEvent event) {
    _currentZoom = event.camera.zoom;
    _scheduleRecomputeVisible();
  }

  void _scheduleRecomputeVisible() {
    _recomputeDebounce?.cancel();
    _recomputeDebounce = Timer(_recomputeDelay, _recomputeVisible);
  }

  void _maybeRecomputeVisible() {
    if (!mounted) return;
    if (!_locationReady) return;
    if (!_mapReady) return;
    if (_allPolygons.isEmpty) return;
    _scheduleRecomputeVisible();
  }

  void _recomputeVisible() {
    if (!mounted) return;
    if (!_mapReady) return;
    if (_allPolygons.isEmpty) return;

    final camera = _mapController.camera;
    final zoom = camera.zoom;
    final showPolys = zoom >= _polygonZoomThreshold;
    final showMarkers = !showPolys && zoom >= _markerZoomThreshold;

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
        if (!_matchesCurrentFilter(p)) {
          continue;
        }
        final intersects =
            !(p.maxLat < minLat ||
                p.minLat > maxLat ||
                p.maxLng < minLng ||
                p.minLng > maxLng);
        if (intersects) visible.add(p);
      }
    } else if (showMarkers) {
      for (final p in _allPolygons) {
        if (!_matchesCurrentFilter(p)) {
          continue;
        }
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
            appBar: AppBar(title: const Text('圃場登録')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('ポリゴン取得に失敗しました: $error'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _reloadPolygons,
                      child: const Text('再読み込み'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final loaded = snapshot.data ?? const <PaddyPolygon>[];
        if (_allPolygons.isEmpty) {
          _allPolygons = loaded;
          _polyByID
            ..clear()
            ..addEntries(loaded.map((p) => MapEntry(p.polyID, p)));
          _selectedPolyIDs.removeWhere((id) => _polyByID[id]?.isInUse ?? false);
          _areaCacheM2.clear();

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _maybeRecomputeVisible();
          });
        }

        if (!_locationReady) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (_allPolygons.isEmpty) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('圃場登録'),
              actions: [
                IconButton(
                  tooltip: '再読み込み',
                  onPressed: _isReloading ? null : _reloadPolygons,
                  icon: _isReloading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                ),
              ],
            ),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('ポリゴンデータがありません'),
              ),
            ),
          );
        }

        final initial = _allPolygons.first.centroid;
        final selectedList = _selectedPolyIDs.toList()..sort();
        final totalAreaM2 = selectedList.fold<double>(0.0, (sum, polyID) {
          final p = _polyByID[polyID];
          if (p == null) return sum;
          return sum + _areaM2Of(p);
        });

        return Scaffold(
          appBar: AppBar(
            title: const Text('圃場登録'),
            actions: [
              IconButton(
                tooltip: '再読み込み',
                onPressed: _isReloading ? null : _reloadPolygons,
                icon: _isReloading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
              ),
              IconButton(
                tooltip: '選択解除',
                onPressed: _selectedPolyIDs.isEmpty ? null : _clearSelection,
                icon: const Icon(Icons.backspace),
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
                      _maybeRecomputeVisible();
                    });
                  },
                  interactionOptions: InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://cyberjapandata.gsi.go.jp/xyz/std/{z}/{x}/{y}.png',
                    userAgentPackageName: 'jp.paddy.admin',
                  ),
                  if (_showPolygons)
                    GestureDetector(
                      behavior: HitTestBehavior.deferToChild,
                      onTap: () {
                        final result = _polyHitNotifier.value;
                        if (result == null || result.hitValues.isEmpty) return;
                        _toggleSelectionByID(result.hitValues.first);
                      },
                      child: PolygonLayer<String>(
                        hitNotifier: _polyHitNotifier,
                        polygons: _visiblePolygons.map((p) {
                          final selected = _selectedPolyIDs.contains(p.polyID);
                          final blocked = p.isInUse;
                          return Polygon<String>(
                            points: p.outerRing,
                            hitValue: p.polyID,
                            color: blocked
                                ? Colors.grey.withAlpha(90)
                                : selected
                                ? Colors.blue.withAlpha(130)
                                : Colors.green.withAlpha(90),
                            borderColor: blocked
                                ? Colors.grey.shade700
                                : selected
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
                            color: p.isInUse ? Colors.grey : Colors.blueGrey,
                          ),
                        );
                      }).toList(),
                    ),
                  RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution(
                        '国土地理院',
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
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            key: ValueKey(
                              'pref-$_selectedPrefectureCode-${_prefectureOptions.length}',
                            ),
                            initialValue: _selectedPrefectureCode,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              isDense: true,
                              labelText: '都道府県',
                            ),
                            items: [
                              ..._prefectureOptions.map(
                                (o) => DropdownMenuItem<String>(
                                  value: o.code,
                                  child: Text(o.name),
                                ),
                              ),
                            ],
                            onChanged: _isReloading
                                ? null
                                : _onPrefectureChanged,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            key: ValueKey(
                              'city-$_selectedLocalGovernmentCode-${_municipalityOptions.length}',
                            ),
                            initialValue: _selectedLocalGovernmentCode.isEmpty
                                ? null
                                : _selectedLocalGovernmentCode,
                            hint: const Text('市町村を選択してください'),
                            isExpanded: true,
                            decoration: const InputDecoration(
                              isDense: true,
                              labelText: '市町村',
                            ),
                            items: [
                              ..._municipalityOptions.map(
                                (o) => DropdownMenuItem<String>(
                                  value: o.code,
                                  child: Text(o.municipalityName),
                                ),
                              ),
                            ],
                            onChanged: _isReloading
                                ? null
                                : _onMunicipalityChanged,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (!_showPolygons)
                Positioned(
                  top: 136,
                  left: 12,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Text(
                        _showMarkers
                            ? 'ズーム ${_polygonZoomThreshold.toStringAsFixed(1)} 以上でポリゴン表示 (現在: ${_currentZoom.toStringAsFixed(1)})'
                            : 'ズーム ${_markerZoomThreshold.toStringAsFixed(1)} 以上で表示 (現在: ${_currentZoom.toStringAsFixed(1)})',
                      ),
                    ),
                  ),
                ),
              if (_filteredPolygonCount == 0 && !_needsMunicipalitySelection)
                Align(
                  alignment: Alignment.center,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: const Text('条件に一致するポリゴンがありません'),
                    ),
                  ),
                ),
              Align(
                alignment: Alignment.bottomCenter,
                child: selectedList.isNotEmpty
                    ? _SelectionBar(
                        selectedPolyIDs: selectedList,
                        totalAreaText: _formatArea(totalAreaM2),
                        areaTextOf: (polyID) {
                          final p = _polyByID[polyID];
                          if (p == null) return '-';
                          return _formatArea(_areaM2Of(p));
                        },
                        onSubmit: _submit,
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LocalGovernmentOption {
  const _LocalGovernmentOption({
    required this.code,
    required this.localGovernmentName,
    required this.prefectureCode,
    required this.prefectureName,
    required this.municipalityName,
  });

  static _LocalGovernmentOption? fromApiRow(Map<String, dynamic> row) {
    final code = (row['local_government_code'] ?? '').toString().trim();
    if (!_PaddyAddFromMapScreenState._codePattern.hasMatch(code)) {
      return null;
    }

    final localGovernmentName = (row['local_government_name'] ?? '')
        .toString()
        .trim();
    final prefectureCode = (row['prefecture_code'] ?? '')
        .toString()
        .trim()
        .padLeft(2, '0');
    final prefectureName = (row['prefecture_name'] ?? '').toString().trim();
    final municipalityName = (row['municipality_name'] ?? '').toString().trim();

    return _LocalGovernmentOption(
      code: code,
      localGovernmentName: localGovernmentName,
      prefectureCode: prefectureCode.isEmpty
          ? code.substring(0, 2)
          : prefectureCode,
      prefectureName: prefectureName.isEmpty
          ? '都道府県(${code.substring(0, 2)})'
          : prefectureName,
      municipalityName: municipalityName.isEmpty
          ? localGovernmentName
          : municipalityName,
    );
  }

  final String code;
  final String localGovernmentName;
  final String prefectureCode;
  final String prefectureName;
  final String municipalityName;
}

class _PrefectureOption {
  const _PrefectureOption({required this.code, required this.name});

  final String code;
  final String name;
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.selectedPolyIDs,
    required this.totalAreaText,
    required this.areaTextOf,
    required this.onSubmit,
  });

  final List<String> selectedPolyIDs;
  final String totalAreaText;
  final String Function(String polyID) areaTextOf;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.all(12),
      child: Card(
        elevation: 6,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '選択 ${selectedPolyIDs.length}件',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (selectedPolyIDs.isNotEmpty)
                    IconButton(
                      tooltip: '選択一覧',
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          showDragHandle: true,
                          builder: (_) {
                            return ListView.separated(
                              itemCount: selectedPolyIDs.length,
                              separatorBuilder: (_, _) =>
                                  const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final polyID = selectedPolyIDs[i];
                                return ListTile(
                                  leading: const Icon(Icons.crop_square),
                                  title: Text('poly_id: $polyID'),
                                  subtitle: Text(
                                    areaTextOf(polyID),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                      icon: const Icon(Icons.list),
                    ),
                  FilledButton.icon(
                    onPressed: onSubmit,
                    icon: const Icon(Icons.check),
                    label: const Text('確定'),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '合計面積  $totalAreaText',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
