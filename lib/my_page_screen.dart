// lib/my_page_screen.dart
import 'package:flutter/material.dart';
import 'common_widgets.dart';

/// ====== 画面: マイページ ======
class MyPageScreen extends StatelessWidget {
  const MyPageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('マイページ')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'プロフィール',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.edit),
                      ),
                    ],
                  ),
                  const Divider(),
                  const _KeyValueRow(k: 'ユーザー名', v: '（仮）'),
                  const _KeyValueRow(k: '登録年月日', v: '（仮）'),
                  const _KeyValueRow(k: '契約圃場数', v: '（仮）'),
                  const _KeyValueRow(k: '支払い方法', v: '（仮）'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: const [
                  Text('支払い履歴', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('ログ\n・\n・\n・\n・'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: '変更',
            onPressed: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('変更（仮）')));
            },
          ),
        ],
      ),
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow({required this.k, required this.v});
  final String k;
  final String v;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(k)),
          Text(v, style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}
