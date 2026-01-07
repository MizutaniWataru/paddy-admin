// lib/detail_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_datetime_picker_plus/flutter_datetime_picker_plus.dart';

import 'data_model.dart';
import 'settings_screen.dart';
import 'table_screen.dart';
import 'app_state.dart';
import 'field_models.dart';

enum ChartDataType { waterLevel, temperature }

// 履歴データ用クラス
class HistoryData {
  final String date;
  final String time;
  final double waterLevel;
  final int temperature;

  HistoryData(this.date, this.time, this.waterLevel, this.temperature);
}

// 詳細画面
class PaddyFieldDetailScreen extends StatefulWidget {
  final PaddyField field;
  const PaddyFieldDetailScreen({super.key, required this.field});
  @override
  State<PaddyFieldDetailScreen> createState() => _PaddyFieldDetailScreenState();
}

class _PaddyFieldDetailScreenState extends State<PaddyFieldDetailScreen> {
  late PaddyField _field;
  bool _dirty = false;
  // --- Stateの管理 ---
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 1));
  DateTime _endDate = DateTime.now();

  final DateFormat formatter = DateFormat('yyyy/MM/dd HH:mm');
  ChartDataType _currentChartType = ChartDataType.waterLevel;
  List<FlSpot> _waterLevelSpots = [];
  List<FlSpot> _temperatureSpots = [];
  List<HistoryData> _historyList = [];
  bool _isDetailsLoading = true;
  String? _detailsError;

  @override
  void initState() {
    super.initState();
    _field = widget.field;
    _fetchDetailsData();
  }

  Future<void> _fetchDetailsData() async {
    setState(() {
      _isDetailsLoading = true;
      _detailsError = null;
    });
    try {
      final fromDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(_startDate);
      final toDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(_endDate);
      final dataUrl =
          'https://dev.amberlogix.co.jp/app/paddy/get_device_data?padid=${widget.field.id}&fromd=$fromDate&tod=$toDate';
      final response = await http.get(Uri.parse(dataUrl));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        final newWaterLevelSpots = <FlSpot>[];
        final newTemperatureSpots = <FlSpot>[];
        final newHistoryList = <HistoryData>[];

        for (var item in data) {
          final measuredDate = DateTime.parse(item['measured_date']);
          final waterLevelMm = (item['waterlevel'] as num?)?.toDouble() ?? 0.0;
          final waterLevelCm = waterLevelMm / 10.0;
          final temperature = (item['temperature'] as num?)?.toDouble();
          newWaterLevelSpots.add(
            FlSpot(
              measuredDate.millisecondsSinceEpoch.toDouble(),
              waterLevelCm,
            ),
          );
          if (temperature != null) {
            newTemperatureSpots.add(
              FlSpot(
                measuredDate.millisecondsSinceEpoch.toDouble(),
                temperature,
              ),
            );
          }
          newHistoryList.add(
            HistoryData(
              DateFormat('MM/dd').format(measuredDate),
              DateFormat('HH:mm').format(measuredDate),
              waterLevelCm,
              temperature?.toInt() ?? 0,
            ),
          );
        }
        setState(() {
          _waterLevelSpots = newWaterLevelSpots;
          _temperatureSpots = newTemperatureSpots;
          _historyList = newHistoryList;
        });
      } else {
        throw Exception('サーバーエラー');
      }
    } catch (e) {
      setState(() {
        _detailsError = 'データ取得に失敗しました: $e';
      });
    } finally {
      setState(() {
        _isDetailsLoading = false;
      });
    }
  }

  Future<void> _showDateTimePicker({required bool isStartDate}) async {
    DatePicker.showDateTimePicker(
      context,
      showTitleActions: true,
      onConfirm: (date) {
        setState(() {
          if (isStartDate) {
            _startDate = date;
          } else {
            _endDate = date;
          }
        });
        _fetchDetailsData();
      },
      currentTime: isStartDate ? _startDate : _endDate,
      locale: LocaleType.jp,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.pop(context, _field);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              Expanded(
                child: Text(_field.name, overflow: TextOverflow.ellipsis),
              ),
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () async {
                  final updated = await Navigator.push<PaddyField>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SettingsScreen(field: _field),
                    ),
                  );
                  if (updated != null && mounted) {
                    setState(() {
                      _field = updated;
                      _dirty = true;
                    });
                  }
                },
              ),
            ],
          ),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 1,
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                // 1. 地図エリア
                SizedBox(
                  height: 250,
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: _field.location,
                      initialZoom: 15,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://cyberjapandata.gsi.go.jp/xyz/std/{z}/{x}/{y}.png',
                        userAgentPackageName: 'dev.flutter_map.example',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _field.location,
                            width: 80,
                            height: 80,
                            child: const Icon(
                              Icons.location_pin,
                              size: 40,
                              color: Colors.red,
                            ),
                          ),
                        ],
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
                ),

                const SizedBox(height: 16),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '表示期間',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Text(formatter.format(_startDate)),
                            IconButton(
                              icon: const Icon(Icons.edit_calendar_outlined),
                              onPressed: () =>
                                  _showDateTimePicker(isStartDate: true),
                              tooltip: '開始日時を変更',
                            ),
                            const Text('〜'),
                            Text(formatter.format(_endDate)),
                            IconButton(
                              icon: const Icon(Icons.edit_calendar_outlined),
                              onPressed: () =>
                                  _showDateTimePicker(isStartDate: false),
                              tooltip: '終了日時を変更',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // 2. グラフ表示エリア
                Container(
                  height: 300,
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      ToggleButtons(
                        isSelected: [
                          _currentChartType == ChartDataType.waterLevel,
                          _currentChartType == ChartDataType.temperature,
                        ],
                        onPressed: (index) {
                          setState(() {
                            _currentChartType = ChartDataType.values[index];
                          });
                        },
                        borderRadius: BorderRadius.circular(8.0),
                        children: const [
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text('水位'),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text('水温'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: _isDetailsLoading
                            ? const Center(child: CircularProgressIndicator())
                            : _detailsError != null
                            ? Center(
                                child: Text(
                                  _detailsError!,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              )
                            : (_currentChartType == ChartDataType.waterLevel
                                      ? _waterLevelSpots
                                      : _temperatureSpots)
                                  .isEmpty
                            ? const Center(child: Text('この期間のデータはありません。'))
                            : LineChart(
                                LineChartData(
                                  lineBarsData: [
                                    LineChartBarData(
                                      spots:
                                          _currentChartType ==
                                              ChartDataType.waterLevel
                                          ? _waterLevelSpots
                                          : _temperatureSpots,
                                      isCurved: true,
                                      color:
                                          _currentChartType ==
                                              ChartDataType.waterLevel
                                          ? Colors.blue
                                          : Colors.orange,
                                      barWidth: 2,
                                      dotData: const FlDotData(show: false),
                                      belowBarData: BarAreaData(
                                        show: true,
                                        color:
                                            (_currentChartType ==
                                                        ChartDataType.waterLevel
                                                    ? Colors.blue
                                                    : Colors.orange)
                                                .withAlpha(51),
                                      ),
                                    ),
                                  ],
                                  titlesData: FlTitlesData(
                                    bottomTitles: AxisTitles(
                                      sideTitles: SideTitles(
                                        showTitles: true,
                                        reservedSize: 30,
                                        interval: 10800000,
                                        getTitlesWidget: (value, meta) {
                                          final dt =
                                              DateTime.fromMillisecondsSinceEpoch(
                                                (value).toInt(),
                                              );

                                          final label = DateFormat(
                                            'HH:mm',
                                          ).format(dt);

                                          return Text(
                                            label,
                                            style: const TextStyle(
                                              fontSize: 10,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    leftTitles: AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                    topTitles: AxisTitles(
                                      sideTitles: SideTitles(showTitles: false),
                                    ),
                                  ),
                                  gridData: FlGridData(
                                    show: true,
                                    drawVerticalLine: true,
                                    verticalInterval: 7200000,
                                    getDrawingVerticalLine: (value) {
                                      return FlLine(
                                        color: Colors.grey.withAlpha(100),
                                        strokeWidth: 1,
                                        dashArray: [4, 2],
                                      );
                                    },
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),

                // 3. テーブル表示ボタン
                Container(
                  padding: const EdgeInsets.all(1.0),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(10)),
                      ),
                    ),
                    child: const Text('データ詳細表示'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TableScreen(
                            field: _field,
                            historyList: _historyList,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FieldDetailScreen extends StatefulWidget {
  const FieldDetailScreen({super.key, required this.fieldId});
  final String fieldId;

  @override
  State<FieldDetailScreen> createState() => _FieldDetailScreenState();
}

class _FieldDetailScreenState extends State<FieldDetailScreen> {
  String range = '1日';

  ChartDataType _chartType = ChartDataType.waterLevel;

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 1));
  DateTime _endDate = DateTime.now();

  bool _isLoading = true;
  String? _error;

  List<FlSpot> _waterLevelSpots = [];
  List<FlSpot> _temperatureSpots = [];

  // zipは固定URLだったけど、後で差し替えやすいように一応定数化
  static const String _baseUrl = String.fromEnvironment(
    'AMBERLOGIX_BASE_URL',
    defaultValue: 'https://dev.amberlogix.co.jp',
  );

  @override
  void initState() {
    super.initState();
    _applyRange();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchDetailsData();
    });
  }

  void _applyRange() {
    final now = DateTime.now();
    final days = (range == '1日')
        ? 1
        : (range == '3日')
        ? 3
        : 7;
    _endDate = now;
    _startDate = now.subtract(Duration(days: days));
  }

  Future<void> _fetchDetailsData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final state = AppStateScope.of(context);
      final field = state.getFieldById(widget.fieldId);

      final fromDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(_startDate);
      final toDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(_endDate);

      final url =
          '$_baseUrl/app/paddy/get_device_data?padid=${field.id}&fromd=$fromDate&tod=$toDate';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        throw Exception('サーバーエラー: ${response.statusCode}');
      }

      final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));

      final newWater = <FlSpot>[];
      final newTemp = <FlSpot>[];

      for (final item in data) {
        final measuredDate = DateTime.parse(item['measured_date']);

        // zip同様：waterlevelはmm → cm
        final waterLevelMm = (item['waterlevel'] as num?)?.toDouble() ?? 0.0;
        final waterLevelCm = waterLevelMm / 10.0;

        final temperature = (item['temperature'] as num?)?.toDouble();

        newWater.add(
          FlSpot(measuredDate.millisecondsSinceEpoch.toDouble(), waterLevelCm),
        );

        if (temperature != null) {
          newTemp.add(
            FlSpot(measuredDate.millisecondsSinceEpoch.toDouble(), temperature),
          );
        }
      }

      if (!mounted) return;

      setState(() {
        _waterLevelSpots = newWater;
        _temperatureSpots = newTemp;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'データ取得に失敗しました: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  LineChartData _buildChartData(List<FlSpot> spots) {
    final cs = Theme.of(context).colorScheme;

    return LineChartData(
      gridData: const FlGridData(show: true),
      titlesData: const FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      lineTouchData: const LineTouchData(enabled: true),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: false,
          barWidth: 2,
          color: cs.primary,
          dotData: const FlDotData(show: false),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final field = state.getFieldById(widget.fieldId);

    final spots = (_chartType == ChartDataType.waterLevel)
        ? _waterLevelSpots
        : _temperatureSpots;

    return Scaffold(
      appBar: AppBar(
        title: Text(field.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FieldSettingsScreen(fieldId: field.id),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'グラフ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),

              PopupMenuButton<ChartDataType>(
                tooltip: '表示切替',
                initialValue: _chartType,
                onSelected: (v) => setState(() => _chartType = v),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: ChartDataType.waterLevel,
                    child: Text('水位'),
                  ),
                  PopupMenuItem(
                    value: ChartDataType.temperature,
                    child: Text('水温'),
                  ),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    _chartType == ChartDataType.waterLevel ? '水位 ▾' : '水温 ▾',
                  ),
                ),
              ),

              DropdownButton<String>(
                value: range,
                items: const [
                  DropdownMenuItem(value: '1日', child: Text('1日')),
                  DropdownMenuItem(value: '3日', child: Text('3日')),
                  DropdownMenuItem(value: '7日', child: Text('7日')),
                ],
                onChanged: (v) {
                  setState(() => range = v ?? '1日');
                  _applyRange();
                  _fetchDetailsData();
                },
              ),
            ],
          ),
          const SizedBox(height: 8),

          Container(
            height: 180,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(12),
            ),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : (_error != null)
                ? Center(child: Text(_error!))
                : (spots.isEmpty)
                ? const Center(child: Text('データがありません'))
                : Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: LineChart(_buildChartData(spots)),
                  ),
          ),

          const SizedBox(height: 16),

          // ===== 作業履歴（今まで通り）=====
          const Text('作業履歴', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (field.works.isEmpty)
            const Text('履歴がありません')
          else
            ...field.works.map((w) => _WorkCard(fieldId: field.id, work: w)),
        ],
      ),
    );
  }
}

class _WorkCard extends StatelessWidget {
  const _WorkCard({required this.fieldId, required this.work});
  final String fieldId;
  final WorkLog work;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  WorkDetailScreen(fieldId: fieldId, workId: work.id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.image_outlined),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${work.timeText}  ${work.actionText}  ${work.title}',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ====== 画面: 作業詳細（写真/コメント） ======
class WorkDetailScreen extends StatefulWidget {
  const WorkDetailScreen({
    super.key,
    required this.fieldId,
    required this.workId,
  });

  final String fieldId;
  final String workId;

  @override
  State<WorkDetailScreen> createState() => _WorkDetailScreenState();
}

class _WorkDetailScreenState extends State<WorkDetailScreen> {
  final ctrl = TextEditingController();

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final field = state.getFieldById(widget.fieldId);
    final work = field.works.firstWhere((w) => w.id == widget.workId);

    return Scaffold(
      appBar: AppBar(title: Text(work.title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(child: Text('ステータス  ${work.status}')),
                Text('担当者  ${work.assignee}'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(child: Text('写真')),
            ),
          ),
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Align(alignment: Alignment.centerLeft, child: Text('コメント')),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: work.comments.length,
              itemBuilder: (_, i) {
                final msg = work.comments[i];
                final isMine = i.isOdd;
                return Align(
                  alignment: isMine
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(10),
                    constraints: const BoxConstraints(maxWidth: 280),
                    decoration: BoxDecoration(
                      color: isMine
                          ? Colors.teal.withValues(alpha: 0.15)
                          : Colors.black12,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(msg),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(child: TextField(controller: ctrl)),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: () {
                      final text = ctrl.text.trim();
                      if (text.isEmpty) return;
                      setState(() {
                        work.comments.add(text);
                        ctrl.clear();
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
