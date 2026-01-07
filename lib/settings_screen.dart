// lib/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';

import 'data_model.dart';
import 'app_state.dart';
import 'common_widgets.dart';
import 'constants.dart';

// 指定した範囲の数値のみ入力を許可するフォーマッター
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
      return oldValue; // 数値以外は許可しない
    }
    if (value >= min && value <= max) {
      return newValue; // 範囲内なら許可
    }
    return oldValue;
  }
}

class SettingsScreen extends StatefulWidget {
  final PaddyField? field;

  const SettingsScreen({super.key, this.field});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _offsetController = TextEditingController();
  final TextEditingController _upperController = TextEditingController();
  final TextEditingController _lowerController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  String? _pickedImagePath;
  bool _enableAlert = false;
  bool _hasChanged = false;

  @override
  void initState() {
    super.initState();

    if (widget.field != null) {
      final f = widget.field!;
      _titleController.text = f.name;
      _offsetController.text = f.offset.toString();
      _upperController.text = f.alertThUpper.toString();
      _lowerController.text = f.alertThLower.toString();
      _enableAlert = f.enableAlert;
    }
  }

  @override
  void dispose() {
    _offsetController.dispose();
    _upperController.dispose();
    _lowerController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text(
            '基本設定',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blueAccent,
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('タイトル'),
            trailing: SizedBox(
              width: 260,
              child: TextField(
                textAlign: TextAlign.end,
                controller: _titleController,
                onChanged: (v) => setState(() => _hasChanged = true),
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 12.0),
                  child: Text('タイトル画像'),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // 画像表示
                      if (_pickedImagePath != null)
                        Image.file(File(_pickedImagePath!))
                      else if (widget.field?.imageUrl != null &&
                          widget.field!.imageUrl.isNotEmpty)
                        Image.network(widget.field!.imageUrl)
                      else
                        Container(
                          height: 150,
                          color: Colors.grey[200],
                          child: const Center(child: Text('No Image')),
                        ),

                      const SizedBox(height: 8),

                      // ボタン類
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _pickedImagePath = null;
                                _hasChanged = true;
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              shape: const CircleBorder(),
                              fixedSize: const Size(40, 40),
                              padding: EdgeInsets.zero,
                            ),
                            child: const Icon(Icons.undo),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(0, 40),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                            ),
                            onPressed: () async {
                              final XFile? picked = await _picker.pickImage(
                                source: ImageSource.gallery,
                              );
                              if (picked != null) {
                                setState(() {
                                  _pickedImagePath = picked.path;
                                  _hasChanged = true;
                                });
                              }
                            },
                            child: const Text('画像を変更'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '水位設定',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blueAccent,
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('水位オフセット'),
            trailing: SizedBox(
              width: 150,
              child: TextField(
                textAlign: TextAlign.end,
                controller: _offsetController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
                ],
                onChanged: (v) => setState(() => _hasChanged = true),
                decoration: const InputDecoration(
                  suffixText: 'mm',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                ),
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('水位アラート'),
            value: _enableAlert,
            onChanged: (value) => setState(() {
              _enableAlert = value;
              _hasChanged = true;
            }),
          ),
          ListTile(
            title: const Text('閾値上限'),
            trailing: SizedBox(
              width: 150,
              child: TextField(
                textAlign: TextAlign.end,
                controller: _upperController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  NumericRangeFormatter(min: 0, max: 30),
                ],
                onChanged: (v) => setState(() => _hasChanged = true),
                decoration: const InputDecoration(
                  suffixText: 'mm',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                ),
              ),
            ),
          ),
          ListTile(
            title: const Text('閾値下限'),
            trailing: SizedBox(
              width: 150,
              child: TextField(
                textAlign: TextAlign.end,
                controller: _lowerController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  NumericRangeFormatter(min: 0, max: 30),
                ],
                onChanged: (v) => setState(() => _hasChanged = true),
                decoration: const InputDecoration(
                  suffixText: 'mm',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _hasChanged
                ? () async {
                    final scaffoldMessenger = ScaffoldMessenger.of(context);
                    final navigator = Navigator.of(context);

                    final Map<String, dynamic> payload = {
                      'padid': widget.field?.id,
                      'paddyname': _titleController.text,
                      'offset': int.tryParse(_offsetController.text) ?? 0,
                      'enable_alert': _enableAlert ? 1 : 0,
                      // ★★★ 修正点: cm→mm変換を削除 ★★★
                      'alert_th_upper':
                          int.tryParse(_upperController.text) ?? 0,
                      'alert_th_lower':
                          int.tryParse(_lowerController.text) ?? 0,
                    };

                    try {
                      final uri = Uri.parse(
                        'https://dev.amberlogix.co.jp/app/paddy/update_device',
                      );
                      final response = await http.post(
                        uri,
                        headers: {'Content-Type': 'application/json'},
                        body: jsonEncode(payload),
                      );

                      debugPrint('payload: ${payload.toString()}');

                      if (response.statusCode == 200) {
                        final updated = widget.field!.copyWith(
                          name: _titleController.text,
                          offset:
                              int.tryParse(_offsetController.text) ??
                              widget.field!.offset,
                          enableAlert: _enableAlert,
                          // ★★★ 修正点: cm→mm変換を削除 ★★★
                          alertThUpper:
                              int.tryParse(_upperController.text) ??
                              widget.field!.alertThUpper,
                          alertThLower:
                              int.tryParse(_lowerController.text) ??
                              widget.field!.alertThLower,
                          // ToDo: 画像更新
                        );

                        scaffoldMessenger.showSnackBar(
                          const SnackBar(content: Text('保存しました')),
                        );
                        navigator.pop(updated);
                      } else {
                        scaffoldMessenger.showSnackBar(
                          SnackBar(
                            content: Text('保存に失敗しました: ${response.statusCode}'),
                          ),
                        );
                      }
                    } catch (e) {
                      scaffoldMessenger.showSnackBar(
                        SnackBar(content: Text('通信エラー: $e')),
                      );
                    }
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              elevation: 2.0,
              disabledBackgroundColor: Colors.grey.shade400,
              disabledForegroundColor: Colors.grey.shade700,
            ),
            child: Text(
              _hasChanged ? '保存' : '変更なし',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
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
  String setMethod = '一括';
  String displayMethod = '相対値';

  bool _loading = true;
  String? _loadError;

  int _serverOffset = 0;
  bool _serverEnableAlert = false;

  final waterUpperCtrl = TextEditingController();
  final waterLowerCtrl = TextEditingController();
  final tempUpperCtrl = TextEditingController();
  final tempLowerCtrl = TextEditingController();

  bool _dirty = false;
  bool _saving = false;
  bool _suppressDirty = false;

  // ★追加：初期状態（ベースライン）
  bool _baselineReady = false;
  late String _baseName;
  late String _basePlan;
  late String _baseSetMethod;
  late String _baseDisplayMethod;
  late int _baseWaterUpper;
  late int _baseWaterLower;
  late int _baseTempUpper;
  late int _baseTempLower;

  int _asInt(TextEditingController c, int fallback) =>
      int.tryParse(c.text.trim()) ?? fallback;

  void _commitBaseline() {
    _baseName = nameCtrl.text.trim();
    _basePlan = plan;
    _baseSetMethod = setMethod;
    _baseDisplayMethod = displayMethod;
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
        nameCtrl.text.trim() != _baseName ||
        plan != _basePlan ||
        setMethod != _baseSetMethod ||
        displayMethod != _baseDisplayMethod ||
        _asInt(waterUpperCtrl, 0) != _baseWaterUpper ||
        _asInt(waterLowerCtrl, 0) != _baseWaterLower ||
        _asInt(tempUpperCtrl, 0) != _baseTempUpper ||
        _asInt(tempLowerCtrl, 0) != _baseTempLower;

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

    final upper = int.tryParse(waterUpperCtrl.text) ?? field.alertThUpper;
    final lower = int.tryParse(waterLowerCtrl.text) ?? field.alertThLower;

    final payload = {
      'padid': widget.fieldId,
      'paddyname': nameCtrl.text.trim().isEmpty
          ? field.name
          : nameCtrl.text.trim(),
      'offset': _serverOffset,
      'enable_alert': _serverEnableAlert ? 1 : 0,
      'alert_th_upper': upper,
      'alert_th_lower': lower,
    };

    try {
      final res = await http.post(
        Uri.parse('$kBaseUrl/app/paddy/update_device'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (res.statusCode != 200) {
        throw Exception('update_device: ${res.statusCode}');
      }

      appState.updateField(
        widget.fieldId,
        name: payload['paddyname'] as String,
        alertThUpper: upper,
        alertThLower: lower,
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
    return WillPopScope(
      onWillPop: _confirmLeaveIfDirty,
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
                setState(() => plan = v ?? plan),
                _recomputeDirty(),
              },
            ),
            const SizedBox(height: 12),
            const Text('設定方法'),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: '一括', label: Text('一括')),
                ButtonSegment(value: '個別', label: Text('個別')),
              ],
              selected: {setMethod},
              onSelectionChanged: (newSelection) {
                setState(() => setMethod = newSelection.first);
                _recomputeDirty();
              },
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
                      setState(() => displayMethod = newSelection.first);
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
      final res = await http.get(Uri.parse('$kBaseUrl/app/paddy/get_devices'));
      if (!mounted) return;
      if (res.statusCode != 200) {
        throw Exception('get_devices: ${res.statusCode}');
      }

      final List<dynamic> list = json.decode(utf8.decode(res.bodyBytes));

      Map<String, dynamic>? found;
      for (final it in list) {
        if (it is Map<String, dynamic> &&
            it['padid'].toString() == widget.fieldId) {
          found = it;
          break;
        }
      }
      if (found == null) {
        throw Exception('対象の圃場が見つかりません (padid=${widget.fieldId})');
      }

      final apiField = PaddyField.fromJson(found);

      // ローカルStateも更新
      final state = AppStateScope.of(context);
      final field = state.getFieldById(widget.fieldId);

      field.name = apiField.name;
      field.offset = apiField.offset;
      field.enableAlert = apiField.enableAlert;
      field.alertThUpper = apiField.alertThUpper;
      field.alertThLower = apiField.alertThLower;

      state.updateField(
        widget.fieldId,
        name: apiField.name,
        offset: apiField.offset,
        enableAlert: apiField.enableAlert,
        alertThUpper: apiField.alertThUpper,
        alertThLower: apiField.alertThLower,
      );

      // UIに反映
      _suppressDirty = true;
      try {
        nameCtrl.text = apiField.name;
        currentCtrl.text = field.waterLevelText;
        waterUpperCtrl.text = apiField.alertThUpper.toString();
        waterLowerCtrl.text = apiField.alertThLower.toString();

        _serverOffset = apiField.offset;
        _serverEnableAlert = apiField.enableAlert;
      } finally {
        _suppressDirty = false;
      }

      if (!mounted) return;
      setState(() {
        _commitBaseline();
      });

      // UIに出さないけど保存で使う
      _serverOffset = apiField.offset;
      _serverEnableAlert = apiField.enableAlert;

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
