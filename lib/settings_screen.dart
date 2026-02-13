// lib/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'app_state.dart';
import 'common_widgets.dart';
import 'constants.dart';

class NumericRangeFormatter extends TextInputFormatter {
  final int min;
  final int max;

  NumericRangeFormatter({required this.min, required this.max});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }
    final int? value = int.tryParse(newValue.text);
    if (value == null) {
      return oldValue;
    }
    if (value >= min && value <= max) {
      return newValue;
    }
    return oldValue;
  }
}

/// ====== 画面: 圃場設定 ======
class FieldSettingsScreen extends StatefulWidget {
  const FieldSettingsScreen({super.key, required this.fieldId});
  final String fieldId;

  @override
  State<FieldSettingsScreen> createState() => _FieldSettingsScreenState();
}

class _FieldSettingsScreenState extends State<FieldSettingsScreen> {
  final nameCtrl = TextEditingController();
  final currentCtrl = TextEditingController(text: '（仮）');

  String plan = 'ベーシック';
  String displayMethod = '相対値';

  bool _loading = true;
  String? _loadError;
  int _contractPlanId = 0;
  int _levelDisplayMode = 1;

  final waterUpperCtrl = TextEditingController();
  final waterLowerCtrl = TextEditingController();
  final tempUpperCtrl = TextEditingController();
  final tempLowerCtrl = TextEditingController();

  bool _dirty = false;
  bool _saving = false;
  bool _suppressDirty = false;

  bool _baselineReady = false;
  late String _baseName;
  late String _basePlan;
  late String _baseDisplayMethod;
  late int _baseWaterUpper;
  late int _baseWaterLower;
  late int _baseTempUpper;
  late int _baseTempLower;

  final remarkCtrl = TextEditingController();
  String drainage = 'なし';

  late String _baseRemark;
  late String _baseDrainage;

  int _asInt(TextEditingController c, int fallback) =>
      int.tryParse(c.text.trim()) ?? fallback;

  int _contractPlanIdFromPlan(String selectedPlan) {
    return selectedPlan == 'スタンダード' ? 2 : 1;
  }

  int _levelDisplayModeFromDisplayMethod(String selectedDisplayMethod) {
    return selectedDisplayMethod == '絶対値' ? 2 : 1;
  }

  void _commitBaseline() {
    _baseName = nameCtrl.text.trim();
    _basePlan = plan;
    _baseDisplayMethod = displayMethod;
    _baseWaterUpper = _asInt(waterUpperCtrl, 0);
    _baseWaterLower = _asInt(waterLowerCtrl, 0);
    _baseTempUpper = _asInt(tempUpperCtrl, 0);
    _baseTempLower = _asInt(tempLowerCtrl, 0);
    _baseRemark = remarkCtrl.text.trim();
    _baseDrainage = drainage;
    _baselineReady = true;
    _dirty = false;
  }

  void _recomputeDirty() {
    if (_suppressDirty || !_baselineReady) return;

    final changed =
        nameCtrl.text.trim() != _baseName ||
        plan != _basePlan ||
        displayMethod != _baseDisplayMethod ||
        _asInt(waterUpperCtrl, 0) != _baseWaterUpper ||
        _asInt(waterLowerCtrl, 0) != _baseWaterLower ||
        _asInt(tempUpperCtrl, 0) != _baseTempUpper ||
        _asInt(tempLowerCtrl, 0) != _baseTempLower ||
        remarkCtrl.text.trim() != _baseRemark ||
        drainage != _baseDrainage;

    if (changed == _dirty) return;
    setState(() => _dirty = changed);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadFromServer());
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    currentCtrl.dispose();
    waterUpperCtrl.dispose();
    waterLowerCtrl.dispose();
    tempUpperCtrl.dispose();
    tempLowerCtrl.dispose();
    remarkCtrl.dispose();
    super.dispose();
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
                final ok = await _saveChanges();
                if (!ctx.mounted) return;
                if (ok) {
                  Navigator.pop(ctx, true);
                } else {
                  Navigator.pop(ctx, false);
                }
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  Future<bool> _saveChanges() async {
    if (_saving) return false;
    setState(() => _saving = true);

    final scaffold = ScaffoldMessenger.of(context);
    final appState = AppStateScope.of(context);
    final field = appState.getFieldById(widget.fieldId);
    final fieldID = int.tryParse(widget.fieldId);
    if (fieldID == null || fieldID <= 0) {
      scaffold.showSnackBar(
        const SnackBar(content: Text('field_id が不正です')),
      );
      setState(() => _saving = false);
      return false;
    }

    final upper = int.tryParse(waterUpperCtrl.text) ?? field.alertThUpper;
    final lower = int.tryParse(waterLowerCtrl.text) ?? field.alertThLower;
    final tempUpper = int.tryParse(tempUpperCtrl.text) ?? 0;
    final tempLower = int.tryParse(tempLowerCtrl.text) ?? 0;

    final payload = {
      'field_id': fieldID,
      'field_name': nameCtrl.text.trim().isEmpty
          ? field.name
          : nameCtrl.text.trim(),
      'up_level_limit': upper,
      'low_level_limit': lower,
      'up_wtemp_limit': tempUpper,
      'low_wtemp_limit': tempLower,
      'contract_plan_id': _contractPlanId > 0
          ? _contractPlanId
          : _contractPlanIdFromPlan(plan),
      'level_display_mode': _levelDisplayMode > 0
          ? _levelDisplayMode
          : _levelDisplayModeFromDisplayMethod(displayMethod),
    };

    try {
      final res = await http.put(
        Uri.parse(
          '$kBaseUrl/api/fields/${Uri.encodeQueryComponent(widget.fieldId)}/settings',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (res.statusCode != 200) {
        throw Exception('update_device: ${res.statusCode}');
      }

      appState.updateField(
        widget.fieldId,
        name: payload['field_name'] as String,
        alertThUpper: upper,
        alertThLower: lower,

        remark: remarkCtrl.text.trim(),
        drainageControl: (drainage == 'あり'),
      );

      if (!mounted) return false;

      setState(() {
        _commitBaseline();
      });

      scaffold.showSnackBar(const SnackBar(content: Text('変更しました')));
      return true;
    } catch (e) {
      if (mounted) {
        scaffold.showSnackBar(SnackBar(content: Text('保存に失敗: $e')));
      }
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
        appBar: AppBar(title: const Text('設定')),
        body: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (_loading) const LinearProgressIndicator(),
            if (_loadError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _loadError!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),

            const SizedBox(height: 12),

            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: '圃場名'),
              onChanged: (_) => _recomputeDirty(),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: currentCtrl,
              decoration: const InputDecoration(labelText: '現在水位'),
              onChanged: (_) => _recomputeDirty(),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: plan,
              decoration: const InputDecoration(labelText: '契約プラン'),
              items: const [
                DropdownMenuItem(value: 'ベーシック', child: Text('ベーシック')),
                DropdownMenuItem(value: 'スタンダード', child: Text('スタンダード')),
              ],
              onChanged: (v) => {
                setState(() {
                  plan = v ?? plan;
                  _contractPlanId = _contractPlanIdFromPlan(plan);
                }),
                _recomputeDirty(),
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: remarkCtrl,
              decoration: const InputDecoration(
                labelText: '備考',
                hintText: '例）現地メモ、追加要望など',
              ),
              maxLines: 3,
              onChanged: (_) => _recomputeDirty(),
            ),

            const SizedBox(height: 12),
            LabeledSection(
              title: '個別設定',
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
                    onSelectionChanged: (newSelection) {
                      setState(() {
                        displayMethod = newSelection.first;
                        _levelDisplayMode = _levelDisplayModeFromDisplayMethod(displayMethod);
                      });
                      _recomputeDirty();
                    },
                  ),

                  const SizedBox(height: 12),
                  TextField(
                    controller: waterUpperCtrl,
                    decoration: const InputDecoration(labelText: '水位上限'),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _recomputeDirty(),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: waterLowerCtrl,
                    decoration: const InputDecoration(labelText: '水位下限'),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _recomputeDirty(),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: tempUpperCtrl,
                    decoration: const InputDecoration(labelText: '水温上限'),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _recomputeDirty(),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: tempLowerCtrl,
                    decoration: const InputDecoration(labelText: '水温下限'),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _recomputeDirty(),
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
                    onSelectionChanged: (newSelection) {
                      setState(() => drainage = newSelection.first);
                      _recomputeDirty();
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            PrimaryButton(
              label: _saving ? '保存中…' : '変更',
              onPressed: (_loading || _saving || !_dirty)
                  ? null
                  : () async {
                      await _saveChanges();
                    },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadFromServer() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final res = await http.get(
        Uri.parse(
          '$kBaseUrl/api/fields/${Uri.encodeQueryComponent(widget.fieldId)}/settings',
        ),
      );
      if (!mounted) return;
      if (res.statusCode != 200) {
        throw Exception('get settings: ${res.statusCode}');
      }

      final Map<String, dynamic> data = json.decode(utf8.decode(res.bodyBytes));
      final fieldName = (data['field_name'] ?? '').toString();
      final upLevelLimit = (data['up_level_limit'] as num?)?.toInt() ?? 0;
      final lowLevelLimit = (data['low_level_limit'] as num?)?.toInt() ?? 0;
      final upWtempLimit = (data['up_wtemp_limit'] as num?)?.toInt() ?? 0;
      final lowWtempLimit = (data['low_wtemp_limit'] as num?)?.toInt() ?? 0;
      final contractPlanId = (data['contract_plan_id'] as num?)?.toInt() ?? 0;
      final levelDisplayMode = (data['level_display_mode'] as num?)?.toInt() ?? 1;

      final state = AppStateScope.of(context);
      final field = state.getFieldById(widget.fieldId);

      field.name = fieldName;
      field.alertThUpper = upLevelLimit;
      field.alertThLower = lowLevelLimit;

      state.updateField(
        widget.fieldId,
        name: fieldName,
        alertThUpper: upLevelLimit,
        alertThLower: lowLevelLimit,
      );

      // UIに反映
      _suppressDirty = true;
      try {
        nameCtrl.text = fieldName;
        currentCtrl.text = field.waterLevelText;
        waterUpperCtrl.text = upLevelLimit.toString();
        waterLowerCtrl.text = lowLevelLimit.toString();
        tempUpperCtrl.text = upWtempLimit.toString();
        tempLowerCtrl.text = lowWtempLimit.toString();
        displayMethod = levelDisplayMode == 2 ? '絶対値' : '相対値';
        _contractPlanId = contractPlanId;
        _levelDisplayMode = levelDisplayMode;

        remarkCtrl.text = field.remark ?? '';
        drainage = (field.drainageControl) ? 'あり' : 'なし';

      } finally {
        _suppressDirty = false;
      }

      if (!mounted) return;
      setState(() {
        _commitBaseline();
      });

      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = '設定の取得に失敗: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }
}
