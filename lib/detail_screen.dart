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
