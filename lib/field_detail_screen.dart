// lib/detail_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'settings_screen.dart';
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
