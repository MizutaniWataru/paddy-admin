import 'package:flutter/material.dart';

import 'app_state.dart';
import 'common_widgets.dart';

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
  const FieldRegisterPlanScreen({super.key, required this.fieldName});

  final String fieldName;

  @override
  State<FieldRegisterPlanScreen> createState() =>
      _FieldRegisterPlanScreenState();
}

class _FieldRegisterPlanScreenState extends State<FieldRegisterPlanScreen> {
  String plan = 'ベーシック';
  final remarkCtrl = TextEditingController();

  @override
  void dispose() {
    remarkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('圃場登録')),
      body: ScreenPadding(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('施肥プラン'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: plan,
              items: const [
                DropdownMenuItem(value: 'ベーシック', child: Text('ベーシック')),
                DropdownMenuItem(value: 'スタンダード', child: Text('スタンダード')),
              ],
              onChanged: (v) => setState(() => plan = v ?? 'ベーシック'),
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
            ),
            const Spacer(),
            PrimaryButton(
              label: '登録申請',
              onPressed: () {
                state.addPendingField(
                  name: widget.fieldName,
                  pref: '',
                  city: '',
                  plan: plan,
                  remark: remarkCtrl.text.trim(),
                );
                Navigator.popUntil(context, (r) => r.isFirst);
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/home',
                  (r) => false,
                );

                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('登録申請しました。')));
              },
            ),
          ],
        ),
      ),
    );
  }
}
