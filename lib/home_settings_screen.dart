// lib/home_settings_screen.dart
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

  // ---- dirty管理 ----
  bool _dirty = false;
  bool _suppressDirty = false;
  bool _baselineReady = false;
  bool _saving = false;

  late String _baseDisplayMethod;
  late String _baseDrainage;
  late int _baseWaterUpper;
  late int _baseWaterLower;
  late int _baseTempUpper;
  late int _baseTempLower;

  int _asInt(TextEditingController c, int fallback) =>
      int.tryParse(c.text.trim()) ?? fallback;

  void _commitBaseline() {
    _baseDisplayMethod = displayMethod;
    _baseDrainage = drainage;
    _baseWaterUpper = _asInt(waterUpperCtrl, 0);
    _baseWaterLower = _asInt(waterLowerCtrl, 0);
    _baseTempUpper = _asInt(tempUpperCtrl, 0);
    _baseTempLower = _asInt(tempLowerCtrl, 0);
    _baselineReady = true;
    _dirty = false;
  }

  void _recomputeDirty() {
    if (_suppressDirty || !_baselineReady) return;

    final changed =
        displayMethod != _baseDisplayMethod ||
        drainage != _baseDrainage ||
        _asInt(waterUpperCtrl, 0) != _baseWaterUpper ||
        _asInt(waterLowerCtrl, 0) != _baseWaterLower ||
        _asInt(tempUpperCtrl, 0) != _baseTempUpper ||
        _asInt(tempLowerCtrl, 0) != _baseTempLower;

    if (changed == _dirty) return;
    setState(() => _dirty = changed);
  }

  Future<bool> _confirmLeaveIfDirty() async {
    if (!_dirty) return true;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('保存しますか？'),
          content: const Text('変更内容が保存されていません。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('破棄'),
            ),
            FilledButton(
              onPressed: () async {
                final ok = await _saveChanges(popAfterSave: true);
                if (!ctx.mounted) return;
                Navigator.pop(ctx, ok);
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  Future<bool> _saveChanges({bool popAfterSave = false}) async {
    if (_saving) return false;
    setState(() => _saving = true);

    try {
      final state = AppStateScope.of(context);

      state.updateBulkSettings(
        displayMethod: displayMethod,
        waterUpper: _asInt(waterUpperCtrl, state.bulkWaterUpper),
        waterLower: _asInt(waterLowerCtrl, state.bulkWaterLower),
        tempUpper: _asInt(tempUpperCtrl, state.bulkTempUpper),
        tempLower: _asInt(tempLowerCtrl, state.bulkTempLower),
        drainageControl: drainage == 'あり',
      );

      if (!mounted) return false;

      setState(() {
        _commitBaseline();
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('保存しました')));

      if (popAfterSave && mounted) {
        Navigator.pop(context);
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存に失敗: $e')));
      }
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _initFromStateOnce() {
    if (_inited) return;
    _inited = true;

    final state = AppStateScope.of(context);

    _suppressDirty = true;
    try {
      displayMethod = state.bulkDisplayMethod;
      drainage = state.bulkDrainageControl ? 'あり' : 'なし';
      waterUpperCtrl.text = state.bulkWaterUpper.toString();
      waterLowerCtrl.text = state.bulkWaterLower.toString();
      tempUpperCtrl.text = state.bulkTempUpper.toString();
      tempLowerCtrl.text = state.bulkTempLower.toString();
    } finally {
      _suppressDirty = false;
    }

    _commitBaseline();

    // 変更検知（TextField）
    waterUpperCtrl.addListener(_recomputeDirty);
    waterLowerCtrl.addListener(_recomputeDirty);
    tempUpperCtrl.addListener(_recomputeDirty);
    tempLowerCtrl.addListener(_recomputeDirty);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initFromStateOnce();
  }

  @override
  void dispose() {
    waterUpperCtrl.dispose();
    waterLowerCtrl.dispose();
    tempUpperCtrl.dispose();
    tempLowerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nav = Navigator.of(context);

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        _confirmLeaveIfDirty().then((ok) {
          if (!ok) return;
          if (!mounted) return;
          nav.pop();
        });
      },
      child: Scaffold(
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
                      _recomputeDirty();
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
                      _recomputeDirty();
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            PrimaryButton(
              label: _saving ? '保存中…' : '保存',
              onPressed: (_saving || !_dirty)
                  ? null
                  : () async {
                      await _saveChanges(popAfterSave: true);
                    },
            ),
          ],
        ),
      ),
    );
  }
}
