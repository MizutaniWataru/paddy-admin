// lib/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';

import 'data_model.dart';

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
