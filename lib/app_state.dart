import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'constants.dart';
import 'data_model.dart';
import 'field_models.dart';

/// ====== App State ======
class AppState extends ChangeNotifier {
  final List<FieldModel> fields = [
    // FieldModel(
    //   id: 'a',
    //   name: '圃場A',
    //   waterLevelText: '水位 12cm',
    //   waterTempText: '水温 18℃',
    //   imageUrl: '',
    //   isPending: false,
    //   works: [
    //     WorkLog(
    //       id: 'w1',
    //       title: '作業A',
    //       timeText: '00時00分',
    //       actionText: '給水開',
    //       status: '完了',
    //       assignee: '○○××',
    //       comments: ['了解です', '写真確認しました'],
    //     ),
    //   ],
    // ),
  ];

  void addPendingField({
    required String name,
    required String pref,
    required String city,
    required String plan,
  }) {
    fields.add(
      FieldModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        waterLevelText: '水位 -',
        waterTempText: '水温 -',
        imageUrl: '',
        isPending: true,
        pendingText: '登録申請中',
        pref: pref,
        city: city,
        plan: plan,
        works: [],
      ),
    );
    notifyListeners();
  }

  void applyPaddyFieldUpdate(PaddyField updated) {
    final idx = fields.indexWhere((f) => f.id == updated.id);
    if (idx == -1) return;
    fields[idx].name = updated.name;
    notifyListeners();
  }

  FieldModel getFieldById(String id) => fields.firstWhere((f) => f.id == id);

  bool isSyncing = false;
  String? syncError;

  bool hasLoadedOnce = false;

  Future<void> syncDevicesAndLatest() async {
    if (isSyncing) return;

    isSyncing = true;
    syncError = null;
    notifyListeners();

    try {
      // 1) 圃場一覧（get_devices）
      final devicesRes = await http.get(
        Uri.parse('$kBaseUrl/app/paddy/get_devices'),
      );
      if (devicesRes.statusCode != 200) {
        throw Exception('圃場一覧(get_devices)の取得に失敗: ${devicesRes.statusCode}');
      }

      final List<dynamic> devicesData = json.decode(
        utf8.decode(devicesRes.bodyBytes),
      );

      // 既存の圃場（申請中含む）を保持しつつ、APIにある圃場をマージ
      final existingById = {for (final f in fields) f.id: f};

      for (final d in devicesData) {
        if (d is! Map<String, dynamic>) continue;

        // zipのPaddyField.fromJsonを使って padid/paddyname を取り出す
        final apiField = PaddyField.fromJson(d);

        final existing = existingById[apiField.id];
        if (existing != null) {
          existing.name = apiField.name;
          existing.imageUrl = apiField.imageUrl;

          existing.offset = apiField.offset;
          existing.enableAlert = apiField.enableAlert;
          existing.alertThUpper = apiField.alertThUpper;
          existing.alertThLower = apiField.alertThLower;

          existing.isPending = false;
          existing.pendingText = null;
        } else {
          fields.add(
            FieldModel(
              id: apiField.id,
              name: apiField.name,
              imageUrl: apiField.imageUrl,
              waterLevelText: '水位 -',
              waterTempText: '水温 -',
              isPending: false,
              works: const [],

              offset: apiField.offset,
              enableAlert: apiField.enableAlert,
              alertThUpper: apiField.alertThUpper,
              alertThLower: apiField.alertThLower,
            ),
          );
        }
      }

      // 2) 各圃場の最新値（get_device_data）
      final now = DateTime.now();
      final toDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
      final fromDate = DateFormat(
        'yyyy-MM-dd HH:mm:ss',
      ).format(now.subtract(const Duration(days: 1)));

      await Future.wait(
        fields.where((f) => !f.isPending).map((f) async {
          try {
            final url =
                '$kBaseUrl/app/paddy/get_device_data?padid=${Uri.encodeQueryComponent(f.id)}'
                '&fromd=${Uri.encodeQueryComponent(fromDate)}'
                '&tod=${Uri.encodeQueryComponent(toDate)}';

            final res = await http.get(Uri.parse(url));
            if (res.statusCode != 200) return;

            final List<dynamic> data = json.decode(utf8.decode(res.bodyBytes));
            if (data.isEmpty) return;

            // measured_date が一番新しいデータを拾う（順番に依存しない）
            Map<String, dynamic>? latest;
            DateTime? latestDt;
            for (final it in data) {
              if (it is! Map<String, dynamic>) continue;
              final md = it['measured_date'];
              if (md == null) continue;

              DateTime dt;
              try {
                dt = DateTime.parse(md.toString());
              } catch (_) {
                continue;
              }

              if (latestDt == null || dt.isAfter(latestDt)) {
                latestDt = dt;
                latest = it;
              }
            }
            if (latest == null) return;

            final waterMm = (latest['waterlevel'] as num?)?.toDouble();
            final waterCm = waterMm == null ? null : (waterMm / 10.0);

            // 温度は「temperatureが入ってる中で一番新しいやつ」を拾う
            Map<String, dynamic>? tempItem;
            DateTime? tempDt;
            for (final it in data) {
              if (it is! Map<String, dynamic>) continue;
              if (it['temperature'] == null) continue;

              final md = it['measured_date'];
              if (md == null) continue;

              DateTime dt;
              try {
                dt = DateTime.parse(md.toString());
              } catch (_) {
                continue;
              }

              if (tempDt == null || dt.isAfter(tempDt)) {
                tempDt = dt;
                tempItem = it;
              }
            }
            final temp = (tempItem?['temperature'] as num?)?.toDouble();

            // カード表示用テキストを更新
            f.waterLevelText = waterCm == null
                ? '水位 -'
                : '水位 ${waterCm.toStringAsFixed(1)}cm';
            f.waterTempText = temp == null
                ? '水温 -'
                : '水温 ${temp.toStringAsFixed(0)}℃';
          } catch (_) {
            // 1圃場の失敗で全体を落とさない
          }
        }),
      );
    } catch (e) {
      syncError = 'APIエラー: $e';
    } finally {
      isSyncing = false;
      hasLoadedOnce = true;
      notifyListeners();
    }
  }

  void updateField(
    String id, {
    String? name,
    int? offset,
    bool? enableAlert,
    int? alertThUpper,
    int? alertThLower,
  }) {
    final f = getFieldById(id);
    if (name != null) f.name = name;
    if (offset != null) f.offset = offset;
    if (enableAlert != null) f.enableAlert = enableAlert;
    if (alertThUpper != null) f.alertThUpper = alertThUpper;
    if (alertThLower != null) f.alertThLower = alertThLower;
    notifyListeners();
  }
}

class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({
    super.key,
    required AppState notifier,
    required super.child,
  }) : super(notifier: notifier);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    if (scope == null || scope.notifier == null) {
      throw StateError('AppStateScope が見つかりません。');
    }
    return scope.notifier!;
  }
}
