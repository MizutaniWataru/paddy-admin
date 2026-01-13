import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_state.dart';
import 'common_widgets.dart';

class NumericRangeFormatter extends TextInputFormatter {
  NumericRangeFormatter({required this.min, required this.max});
  final int min;
  final int max;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    final v = int.tryParse(newValue.text);
    if (v == null) return oldValue;
    if (v < min || v > max) return oldValue;
    return newValue;
  }
}

/// ホーム左上：一括設定（＝圃場設定の「個別」項目と同じ）
class HomeBulkSettingsScreen extends StatefulWidget {
  const HomeBulkSettingsScreen({super.key});

  @override
  State<HomeBulkSettingsScreen> createState() => _HomeBulkSettingsScreenState();
}

class _HomeBulkSettingsScreenState extends State<HomeBulkSettingsScreen> {
  bool _inited = false;

  String displayMethod = '相対値';
  String drainage = 'なし';

  final waterUpperCtrl = TextEditingController();
  final waterLowerCtrl = TextEditingController();
  final tempUpperCtrl = TextEditingController();
  final tempLowerCtrl = TextEditingController();

  @override
  void dispose() {
    waterUpperCtrl.dispose();
    waterLowerCtrl.dispose();
    tempUpperCtrl.dispose();
    tempLowerCtrl.dispose();
    super.dispose();
  }

  int _asInt(TextEditingController c, int fallback) =>
      int.tryParse(c.text.trim()) ?? fallback;

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    // 初期値をAppStateから一回だけ流し込む
    if (!_inited) {
      _inited = true;
      displayMethod = state.bulkDisplayMethod;
      drainage = state.bulkDrainageControl ? 'あり' : 'なし';
      waterUpperCtrl.text = state.bulkWaterUpper.toString();
      waterLowerCtrl.text = state.bulkWaterLower.toString();
      tempUpperCtrl.text = state.bulkTempUpper.toString();
      tempLowerCtrl.text = state.bulkTempLower.toString();
    }

    return Scaffold(
      appBar: AppBar(title: const Text('設定（全体）')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          LabeledSection(
            title: '個別設定（全体のデフォルト）',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('水位表示方法'),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: '相対値', label: Text('相対値')),
                    ButtonSegment(value: '絶対値', label: Text('絶対値')),
                  ],
                  selected: {displayMethod},
                  onSelectionChanged: (s) {
                    setState(() => displayMethod = s.first);
                  },
                ),

                const SizedBox(height: 12),
                TextField(
                  controller: waterUpperCtrl,
                  decoration: const InputDecoration(labelText: '水位上限'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: waterLowerCtrl,
                  decoration: const InputDecoration(labelText: '水位下限'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: tempUpperCtrl,
                  decoration: const InputDecoration(labelText: '水温上限'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: tempLowerCtrl,
                  decoration: const InputDecoration(labelText: '水温下限'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),

                const SizedBox(height: 12),
                const Text('排水制御'),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'なし', label: Text('なし')),
                    ButtonSegment(value: 'あり', label: Text('あり')),
                  ],
                  selected: {drainage},
                  onSelectionChanged: (s) {
                    setState(() => drainage = s.first);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          PrimaryButton(
            label: '保存',
            onPressed: () {
              state.updateBulkSettings(
                displayMethod: displayMethod,
                waterUpper: _asInt(waterUpperCtrl, state.bulkWaterUpper),
                waterLower: _asInt(waterLowerCtrl, state.bulkWaterLower),
                tempUpper: _asInt(tempUpperCtrl, state.bulkTempUpper),
                tempLower: _asInt(tempLowerCtrl, state.bulkTempLower),
                drainageControl: drainage == 'あり',
              );

              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('保存しました')));
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
