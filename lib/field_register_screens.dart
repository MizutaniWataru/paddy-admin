// lib/field_register_screens.dart
import 'package:flutter/material.dart';
import 'common_widgets.dart';
import 'app_state.dart';

/// ====== 画面: 圃場登録（地図/都道府県/市区町村 → 次へ） ======
class FieldRegisterMapScreen extends StatefulWidget {
  const FieldRegisterMapScreen({super.key});

  @override
  State<FieldRegisterMapScreen> createState() => _FieldRegisterMapScreenState();
}

class _FieldRegisterMapScreenState extends State<FieldRegisterMapScreen> {
  final prefCtrl = TextEditingController(text: '長野県');
  final cityCtrl = TextEditingController(text: '（市区町村）');
  final nameCtrl = TextEditingController(text: '圃場B');

  @override
  void dispose() {
    prefCtrl.dispose();
    cityCtrl.dispose();
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
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: prefCtrl,
                    decoration: const InputDecoration(labelText: '都道府県'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: cityCtrl,
                    decoration: const InputDecoration(labelText: '市区町村'),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: '圃場名'),
            ),
          ),
          const SizedBox(height: 10),
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
                      builder: (_) => FieldRegisterPlanScreen(
                        pref: prefCtrl.text.trim(),
                        city: cityCtrl.text.trim(),
                        fieldName: nameCtrl.text.trim().isEmpty
                            ? '圃場B'
                            : nameCtrl.text.trim(),
                      ),
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

/// ====== 画面: 圃場登録（契約プラン → 登録申請） ======
class FieldRegisterPlanScreen extends StatefulWidget {
  const FieldRegisterPlanScreen({
    super.key,
    required this.pref,
    required this.city,
    required this.fieldName,
  });

  final String pref;
  final String city;
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
            const Text('契約プラン'),
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
                hintText: '地域ルールや水門開閉の注意点など',
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
                  pref: widget.pref,
                  city: widget.city,
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
                ).showSnackBar(const SnackBar(content: Text('登録申請しました（仮）')));
              },
            ),
          ],
        ),
      ),
    );
  }
}
