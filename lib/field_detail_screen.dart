// lib/detail_screen.dart

import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'settings_screen.dart';
import 'app_state.dart';
import 'field_models.dart';
import 'constants.dart';

enum ChartDataType { waterLevel, temperature }
enum ChartRange { day1, day3, day7 }

// 履歴データ用クラス
class HistoryData {
  final String date;
  final String time;
  final double waterLevel;
  final int temperature;

  HistoryData(this.date, this.time, this.waterLevel, this.temperature);
}

class FieldDetailScreen extends StatefulWidget {
  const FieldDetailScreen({super.key, required this.fieldId});
  final String fieldId;

  @override
  State<FieldDetailScreen> createState() => _FieldDetailScreenState();
}

class _FieldDetailScreenState extends State<FieldDetailScreen> {
  static const Duration _jstOffset = Duration(hours: 9);

  ChartDataType _chartType = ChartDataType.waterLevel;
  ChartRange _chartRange = ChartRange.day1;

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 1));
  DateTime _endDate = DateTime.now();

  bool _isLoading = true;
  String? _error;

  List<FlSpot> _waterLevelSpots = [];
  List<FlSpot> _temperatureSpots = [];

  // 初期表示時に最新データを取得
  @override
  void initState() {
    super.initState();
    _applyRange();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchDetailsData();
    });
  }

  void _applyRange() {
    final nowUtc = DateTime.now().toUtc();
    _endDate = nowUtc;
    switch (_chartRange) {
      case ChartRange.day1:
        _startDate = nowUtc.subtract(const Duration(days: 1));
        break;
      case ChartRange.day3:
        _startDate = nowUtc.subtract(const Duration(days: 3));
        break;
      case ChartRange.day7:
        _startDate = nowUtc.subtract(const Duration(days: 7));
        break;
    }
  }

  void _setChartRange(ChartRange range) {
    if (_chartRange == range) return;
    setState(() {
      _chartRange = range;
      _applyRange();
    });
    _fetchDetailsData();
  }

  double _xAxisIntervalMillis() {
    switch (_chartRange) {
      case ChartRange.day1:
        return const Duration(hours: 3).inMilliseconds.toDouble();
      case ChartRange.day3:
        return const Duration(hours: 12).inMilliseconds.toDouble();
      case ChartRange.day7:
        return const Duration(days: 1).inMilliseconds.toDouble();
    }
  }

  String _xAxisLabel(DateTime dtJst) {
    switch (_chartRange) {
      case ChartRange.day1:
        return '${dtJst.hour.toString().padLeft(2, '0')}時';
      case ChartRange.day3:
        return '${dtJst.month}/${dtJst.day} ${dtJst.hour.toString().padLeft(2, '0')}時';
      case ChartRange.day7:
        return '${dtJst.month}/${dtJst.day}';
    }
  }

  String _chartRangeLabel(ChartRange range) {
    switch (range) {
      case ChartRange.day1:
        return '1日';
      case ChartRange.day3:
        return '3日';
      case ChartRange.day7:
        return '7日';
    }
  }

  Future<void> _fetchDetailsData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final state = AppStateScope.of(context);
      final field = state.getFieldById(widget.fieldId);

      final fromDate = DateFormat(
        'yyyy-MM-dd HH:mm:ss',
      ).format(_startDate.add(_jstOffset));
      final toDate = DateFormat(
        'yyyy-MM-dd HH:mm:ss',
      ).format(_endDate.add(_jstOffset));

      final url =
          '$kBaseUrl/api/fields/${Uri.encodeQueryComponent(field.id)}/data?fromd=${Uri.encodeQueryComponent(fromDate)}&tod=${Uri.encodeQueryComponent(toDate)}';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        throw Exception('サーバーエラー: ${response.statusCode}');
      }

      final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));

      final newWater = <FlSpot>[];
      final newTemp = <FlSpot>[];

      for (final item in data) {
        final measuredDateRaw = item['measured_date'];
        if (measuredDateRaw == null) continue;
        final measuredDate = DateTime.parse(
          measuredDateRaw.toString(),
        ).toUtc();

        // API の waterlevel は mm 単位のため、グラフ表示用に cm に変換する
        final waterLevelMm = (item['waterlevel'] as num?)?.toDouble();
        final temperature = (item['temperature'] as num?)?.toDouble();

        if (waterLevelMm != null) {
          final waterLevelCm = waterLevelMm / 10.0;
          newWater.add(
            FlSpot(measuredDate.millisecondsSinceEpoch.toDouble(), waterLevelCm),
          );
        }

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
    if (spots.isEmpty) {
      return LineChartData(
        lineBarsData: const [],
        titlesData: const FlTitlesData(show: false),
      );
    }

    final isTemperature = _chartType == ChartDataType.temperature;
    final lineColor = isTemperature
        ? const Color(0xFFF5A24A)
        : const Color(0xFF7F95D8);
    final fillTopColor = isTemperature
        ? const Color(0x55F5A24A)
        : const Color(0x557F95D8);
    final fillBottomColor = isTemperature
        ? const Color(0x11F5A24A)
        : const Color(0x117F95D8);
    const gridColor = Color(0xFFE8ECF5);
    const axisTextColor = Color(0xFF8A92A0);
    const axisTextStyle = TextStyle(
      fontSize: 10,
      color: axisTextColor,
      fontWeight: FontWeight.w500,
    );

    final minX = _startDate.millisecondsSinceEpoch.toDouble();
    final maxX = _endDate.millisecondsSinceEpoch.toDouble();

    double minY;
    double maxY;
    double yInterval;
    if (_chartType == ChartDataType.waterLevel) {
      // API returns waterlevel in mm; the graph converts to cm and keeps fixed 0-30cm.
      minY = 0;
      maxY = 30;
      yInterval = 10;
    } else {
      final minYValue = spots.map((s) => s.y).reduce(math.min);
      final maxYValue = spots.map((s) => s.y).reduce(math.max);
      final ySpan = (maxYValue - minYValue).abs();
      final yPadding = math.max(1.0, ySpan * 0.25);
      minY = math.max(0.0, (minYValue - yPadding).floorToDouble());
      maxY = (maxYValue + yPadding).ceilToDouble();
      yInterval = (maxY - minY) <= 0 ? 1.0 : (maxY - minY) / 4.0;
    }

    final xInterval = _xAxisIntervalMillis();

    return LineChartData(
      minX: minX,
      maxX: maxX,
      minY: minY,
      maxY: maxY,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: yInterval,
        getDrawingHorizontalLine: (_) =>
            const FlLine(color: gridColor, strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 28,
            interval: yInterval,
            getTitlesWidget: (value, meta) {
              return Text(value.round().toString(), style: axisTextStyle);
            },
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 22,
            interval: xInterval,
            minIncluded: false,
            maxIncluded: true,
            getTitlesWidget: (value, meta) {
              final dtJst = DateTime.fromMillisecondsSinceEpoch(
                value.toInt(),
                isUtc: true,
              ).add(_jstOffset);
              final label = _xAxisLabel(dtJst);
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(label, style: axisTextStyle),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      lineTouchData: LineTouchData(
        enabled: true,
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((touchedSpot) {
              final text = isTemperature
                  ? touchedSpot.y.round().toString()
                  : touchedSpot.y.toStringAsFixed(1);
              return LineTooltipItem(
                text,
                TextStyle(
                  color: lineColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              );
            }).toList();
          },
        ),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.25,
          barWidth: 2.2,
          color: lineColor,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [fillTopColor, fillBottomColor],
            ),
          ),
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
                    _chartType == ChartDataType.waterLevel ? '水位 cm' : '水温 ℃',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF2FA),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<ChartRange>(
                    value: _chartRange,
                    onChanged: (v) {
                      if (v == null) return;
                      _setChartRange(v);
                    },
                    items: ChartRange.values
                        .map(
                          (v) => DropdownMenuItem<ChartRange>(
                            value: v,
                            child: Text(_chartRangeLabel(v)),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Container(
            height: 180,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FB),
              border: Border.all(color: const Color(0xFFDDE3F0)),
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

          // ===== 作業履歴 =====
          const Text('作業履歴', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (field.works.isEmpty)
            const Text('作業履歴がありません')
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

/// ====== 画面: 作業詳細（コメント）======
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
              child: const Center(child: Text('画像')),
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

