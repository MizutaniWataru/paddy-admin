import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'common_widgets.dart';
import 'constants.dart';

class _OwnerInfo {
  const _OwnerInfo({
    required this.ownerId,
    required this.ownerName,
    required this.registDate,
    required this.paymentMethod,
    required this.accountStatus,
  });

  final String ownerId;
  final String ownerName;
  final DateTime registDate;
  final int paymentMethod;
  final int accountStatus;

  static int _asInt(dynamic v, {int fallback = 0}) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? fallback;
  }

  factory _OwnerInfo.fromJson(Map<String, dynamic> json) {
    final ownerId = (json['owner_id'] ?? '').toString();
    final ownerName = (json['owner_name'] ?? '').toString();
    final registDateRaw = (json['regist_date'] ?? '').toString();
    final registDate = DateTime.tryParse(registDateRaw) ?? DateTime(1970);

    return _OwnerInfo(
      ownerId: ownerId,
      ownerName: ownerName,
      registDate: registDate,
      paymentMethod: _asInt(json['payment_method']),
      accountStatus: _asInt(json['account_status']),
    );
  }
}

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  bool _loading = true;
  String? _error;
  _OwnerInfo? _owner;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadOwnerInfo());
  }

  String _paymentMethodText(int code) {
    switch (code) {
      case 1:
        return 'クレジットカード';
      case 2:
        return '銀行振込';
      default:
        return '-';
    }
  }

  String _accountStatusText(int code) {
    switch (code) {
      case 1:
        return 'アクティブ';
      case 2:
        return '休止';
      case 3:
        return '解約';
      default:
        return '-';
    }
  }

  String _formatDate(DateTime value) {
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$y/$m/$d';
  }

  Future<void> _loadOwnerInfo() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final uri = Uri.parse(
        '$kBaseUrl/api/owners/me',
      ).replace(queryParameters: {'owner_id': kDebugOwnerId});

      final res = await http.get(
        uri,
        headers: {kDebugOwnerHeaderName: kDebugOwnerId},
      );

      if (res.statusCode != 200) {
        throw Exception('owner fetch failed: ${res.statusCode}');
      }

      final decoded = json.decode(utf8.decode(res.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('invalid owner response');
      }

      final owner = _OwnerInfo.fromJson(decoded);
      if (!mounted) return;
      setState(() {
        _owner = owner;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'アカウント情報の取得に失敗: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final owner = _owner;

    return Scaffold(
      appBar: AppBar(title: const Text('マイページ')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
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
                        onPressed: _loading ? null : _loadOwnerInfo,
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  const Divider(),
                  _KeyValueRow(k: 'オーナーID', v: owner?.ownerId ?? '-'),
                  _KeyValueRow(k: 'ユーザー名', v: owner?.ownerName ?? '-'),
                  _KeyValueRow(
                    k: '登録年月日',
                    v: owner == null ? '-' : _formatDate(owner.registDate),
                  ),
                  _KeyValueRow(
                    k: '支払い方法',
                    v: owner == null ? '-' : _paymentMethodText(owner.paymentMethod),
                  ),
                  _KeyValueRow(
                    k: 'アカウントステータス',
                    v: owner == null ? '-' : _accountStatusText(owner.accountStatus),
                  ),
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
            label: '再読み込み',
            onPressed: _loading ? null : _loadOwnerInfo,
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
