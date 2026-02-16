import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../module/app_state.dart';
import '../module/constants.dart';
import '../widgets/common_widgets.dart';

class FieldRegisterMapScreen extends StatefulWidget {
  const FieldRegisterMapScreen({super.key});

  @override
  State<FieldRegisterMapScreen> createState() => _FieldRegisterMapScreenState();
}

class _FieldRegisterMapScreenState extends State<FieldRegisterMapScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('圃場登録')),
      body: Column(
        children: [
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
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const FieldRegisterPlanScreen(),
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
  const FieldRegisterPlanScreen({super.key, this.selectedPolyIds = const []});

  final List<String> selectedPolyIds;

  @override
  State<FieldRegisterPlanScreen> createState() =>
      _FieldRegisterPlanScreenState();
}

class _RegisterSubmitResult {
  const _RegisterSubmitResult({
    required this.ok,
    this.errorMessage,
    this.createdCount = 0,
    this.unassignedCount = 0,
  });

  final bool ok;
  final String? errorMessage;
  final int createdCount;
  final int unassignedCount;
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

  List<int> _selectedPolyIDs() {
    if (widget.selectedPolyIds.isEmpty) return const [];

    final ids = <int>[];
    for (final raw in widget.selectedPolyIds) {
      final parsed = int.tryParse(raw);
      if (parsed == null || parsed <= 0) {
        throw const FormatException('poly_id must be numeric');
      }
      ids.add(parsed);
    }
    return ids;
  }

  String _autoFieldName(int index, {int? polyID}) {
    if (polyID != null) {
      return '圃場-$polyID';
    }
    return '圃場-$index';
  }

  Map<String, dynamic>? _decodeJsonMap(http.Response res) {
    if (res.bodyBytes.isEmpty) return null;
    try {
      final decoded = json.decode(utf8.decode(res.bodyBytes));
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.cast<String, dynamic>();
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<_RegisterSubmitResult> _submitRegisterRequest() async {
    final selectedPolyIDs = _selectedPolyIDs();
    final requestCount = selectedPolyIDs.isEmpty ? 1 : selectedPolyIDs.length;
    final uri = Uri.parse('$kBaseUrl$_registerPathDefault');

    var createdCount = 0;
    var unassignedCount = 0;

    for (var i = 0; i < requestCount; i++) {
      final polyID = selectedPolyIDs.isEmpty ? null : selectedPolyIDs[i];
      final payload = <String, dynamic>{
        'field_name': _autoFieldName(i + 1, polyID: polyID),
        'plan': plan,
        'remark': remarkCtrl.text.trim(),
        'owner_id': kDebugOwnerId,
      };
      if (polyID != null) {
        payload['poly_id'] = polyID;
      }

      final res = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          kDebugOwnerHeaderName: kDebugOwnerId,
        },
        body: jsonEncode(payload),
      );

      final bodyMap = _decodeJsonMap(res);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        final message = (bodyMap?['error'] ?? 'registration request failed')
            .toString();
        return _RegisterSubmitResult(
          ok: false,
          createdCount: createdCount,
          unassignedCount: unassignedCount,
          errorMessage: polyID == null ? message : 'poly_id=$polyID: $message',
        );
      }

      final assignment = bodyMap?['sensor_assignment'];
      if (assignment is Map) {
        final assignmentMap = assignment.cast<dynamic, dynamic>();
        final status = assignmentMap['status']?.toString().toLowerCase();
        if (status == 'unassigned') {
          unassignedCount++;
        }
      }
      createdCount++;
    }

    return _RegisterSubmitResult(
      ok: true,
      createdCount: createdCount,
      unassignedCount: unassignedCount,
    );
  }

  Future<void> _onSubmit() async {
    if (_submitting) return;

    final state = AppStateScope.of(context);
    final messenger = ScaffoldMessenger.of(context);

    setState(() => _submitting = true);
    try {
      final result = await _submitRegisterRequest();
      if (!mounted) return;

      if (!result.ok) {
        final partial = result.createdCount > 0
            ? ' (${result.createdCount}件登録済み)'
            : '';
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '${result.errorMessage ?? 'registration request failed'}$partial',
            ),
          ),
        );
        return;
      }

      await state.syncDevicesAndLatest();
      if (!mounted) return;

      Navigator.popUntil(context, (r) => r.isFirst);
      Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false);

      final suffix = result.unassignedCount > 0
          ? ' / センサー未割当: ${result.unassignedCount}件'
          : '';
      messenger.showSnackBar(
        SnackBar(content: Text('登録申請を送信しました (${result.createdCount}件)$suffix')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('registration request failed: $e')),
      );
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
            Text(
              widget.selectedPolyIds.isEmpty
                  ? '圃場名は自動で設定されます。'
                  : '選択したポリゴンごとに圃場名を自動で設定します。',
            ),
            const SizedBox(height: 12),
            const Text('利用プラン'),
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
                hintText: '地図ルール、補足など',
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
                label: _submitting ? '送信中...' : '登録申請',
                onPressed: _submitting ? null : _onSubmit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
