import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'app_state.dart';
import 'common_widgets.dart';
import 'constants.dart';

class FieldRegisterMapScreen extends StatefulWidget {
  const FieldRegisterMapScreen({super.key});

  @override
  State<FieldRegisterMapScreen> createState() => _FieldRegisterMapScreenState();
}

class _FieldRegisterMapScreenState extends State<FieldRegisterMapScreen> {
  final nameCtrl = TextEditingController(text: '圃場');

  @override
  void dispose() {
    nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('圃場登録')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: '圃場名'),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(child: Icon(Icons.map_outlined, size: 64)),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: PrimaryButton(
                label: '次へ',
                onPressed: () {
                  final fieldName = nameCtrl.text.trim().isEmpty
                      ? '圃場'
                      : nameCtrl.text.trim();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          FieldRegisterPlanScreen(fieldName: fieldName),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FieldRegisterPlanScreen extends StatefulWidget {
  const FieldRegisterPlanScreen({
    super.key,
    required this.fieldName,
    this.selectedPolyIds = const [],
  });

  final String fieldName;
  final List<String> selectedPolyIds;

  @override
  State<FieldRegisterPlanScreen> createState() =>
      _FieldRegisterPlanScreenState();
}

class _FieldRegisterPlanScreenState extends State<FieldRegisterPlanScreen> {
  static const String _registerPathDefault = '/api/fields';

  String plan = 'ベーシック';
  final remarkCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    remarkCtrl.dispose();
    super.dispose();
  }

  int? _firstSelectedPolyID() {
    if (widget.selectedPolyIds.isEmpty) return null;
    return int.tryParse(widget.selectedPolyIds.first);
  }

  Future<bool> _submitRegisterRequest() async {
    final firstPolyID = _firstSelectedPolyID();
    if (widget.selectedPolyIds.isNotEmpty && firstPolyID == null) {
      throw const FormatException('poly_id must be numeric');
    }

    final uri = Uri.parse('$kBaseUrl$_registerPathDefault');
    final payload = <String, dynamic>{
      'field_name': widget.fieldName,
      'plan': plan,
      'remark': remarkCtrl.text.trim(),
      'owner_id': kDebugOwnerId,
    };
    if (firstPolyID != null) {
      payload['poly_id'] = firstPolyID;
    }

    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        kDebugOwnerHeaderName: kDebugOwnerId,
      },
      body: jsonEncode(payload),
    );

    return res.statusCode >= 200 && res.statusCode < 300;
  }

  Future<void> _onSubmit() async {
    if (_submitting) return;

    final state = AppStateScope.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _submitting = true);
    try {
      final ok = await _submitRegisterRequest();
      if (!mounted) return;

      if (!ok) {
        messenger.showSnackBar(
          const SnackBar(content: Text('登録申請に失敗しました。時間をおいて再試行してください。')),
        );
        return;
      }

      await state.syncDevicesAndLatest();
      if (!mounted) return;

      Navigator.popUntil(context, (r) => r.isFirst);
      Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false);
      messenger.showSnackBar(const SnackBar(content: Text('登録申請しました。')));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('登録申請に失敗しました: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('圃場登録')),
      body: ScreenPadding(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('契約プラン'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: plan,
              items: const [
                DropdownMenuItem(value: 'ベーシック', child: Text('ベーシック')),
                DropdownMenuItem(value: 'スタンダード', child: Text('スタンダード')),
              ],
              onChanged: _submitting
                  ? null
                  : (v) => setState(() => plan = v ?? 'ベーシック'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: remarkCtrl,
              decoration: const InputDecoration(
                labelText: '備考',
                hintText: '地図ルールや期間条件のメモなど',
              ),
              maxLines: 3,
              textInputAction: TextInputAction.newline,
              enabled: !_submitting,
            ),
            const Spacer(),
            const SizedBox(height: 8),
            SafeArea(
              minimum: const EdgeInsets.only(bottom: 10),
              top: false,
              child: PrimaryButton(
                label: _submitting ? '送信中…' : '登録申請',
                onPressed: _submitting ? null : _onSubmit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
