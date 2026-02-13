import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'constants.dart';
import 'data_model.dart';
import 'field_models.dart';

/// ====== App State ======
class AppState extends ChangeNotifier {
  final List<FieldModel> fields = [];

  void addPendingField({
    required String name,
    required String pref,
    required String city,
    required String plan,
    String? remark,
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
        remark: remark,
        drainageControl: false,
      ),
    );
    notifyListeners();
  }

  void applyFieldUpdate(FieldData updated) {
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
      final fieldsUri = Uri.parse(
        '$kBaseUrl/api/fields',
      ).replace(queryParameters: {'owner_id': kDebugOwnerId});
      final devicesRes = await http.get(
        fieldsUri,
        headers: {kDebugOwnerHeaderName: kDebugOwnerId},
      );
      if (devicesRes.statusCode != 200) {
        throw Exception('field list fetch failed: ${devicesRes.statusCode}');
      }

      final List<dynamic> devicesData = json.decode(
        utf8.decode(devicesRes.bodyBytes),
      );

      final existingById = {for (final f in fields) f.id: f};
      final seenIds = <String>{};

      for (final d in devicesData) {
        if (d is! Map<String, dynamic>) continue;

        final apiField = FieldData.fromJson(d);
        if (apiField.id.isEmpty) continue;
        seenIds.add(apiField.id);

        final waterLevelText = _formatWaterLevelText(apiField.waterLevel);
        final waterTempText = _formatWaterTempText(apiField.temperature);

        final existing = existingById[apiField.id];
        if (existing != null) {
          existing.name = apiField.name;
          existing.imageUrl = apiField.imageUrl;
          existing.waterLevelText = waterLevelText;
          existing.waterTempText = waterTempText;

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
              waterLevelText: waterLevelText,
              waterTempText: waterTempText,
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

      // Keep pending registrations, remove stale non-pending entries.
      fields.removeWhere((f) => !f.isPending && !seenIds.contains(f.id));

      final tasksUri = Uri.parse(
        '$kBaseUrl/api/tasks',
      ).replace(queryParameters: {'owner_id': kDebugOwnerId});
      final tasksRes = await http.get(
        tasksUri,
        headers: {kDebugOwnerHeaderName: kDebugOwnerId},
      );
      if (tasksRes.statusCode != 200) {
        throw Exception('task list fetch failed: ${tasksRes.statusCode}');
      }

      final List<dynamic> tasksData = json.decode(
        utf8.decode(tasksRes.bodyBytes),
      );
      final requestMap = <String, OpenCloseRequest>{};
      for (final row in tasksData) {
        if (row is! Map<String, dynamic>) continue;

        final fieldID = (row['target_field_id'] ?? '').toString();
        if (fieldID.isEmpty) continue;
        if (requestMap.containsKey(fieldID)) continue;

        DateTime scheduledAt = DateTime.now();
        final executionDateRaw = row['execution_date'];
        if (executionDateRaw != null) {
          final parsed = DateTime.tryParse(executionDateRaw.toString());
          if (parsed != null) {
            scheduledAt = parsed.toLocal();
          }
        }

        final taskType = _parseIntOrNull(row['task_type']);
        requestMap[fieldID] = OpenCloseRequest(
          action: _actionTextFromTaskType(taskType),
          scheduledAt: scheduledAt,
        );
      }
      _openCloseRequests
        ..clear()
        ..addAll(requestMap);
    } catch (e) {
      syncError = 'API error: $e';
    } finally {
      isSyncing = false;
      hasLoadedOnce = true;
      notifyListeners();
    }
  }

  String _formatWaterLevelText(double? waterLevelMm) {
    if (waterLevelMm == null) return '水位 -';
    final waterLevelCm = waterLevelMm / 10.0;
    return '水位 ${waterLevelCm.toStringAsFixed(1)}cm';
  }

  String _formatWaterTempText(int? waterTempC) {
    if (waterTempC == null) return '水温 -';
    return '水温 $waterTempC℃';
  }

  int? _parseIntOrNull(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  String _actionTextFromTaskType(int? taskType) {
    switch (taskType) {
      case 1:
        return '給水開ける';
      case 2:
        return '給水閉じる';
      case 3:
        return '排水開ける';
      case 4:
        return '排水閉じる';
      default:
        return '';
    }
  }

  void updateField(
    String id, {
    String? name,
    int? offset,
    bool? enableAlert,
    int? alertThUpper,
    int? alertThLower,
    String? remark,
    bool? drainageControl,
  }) {
    final f = getFieldById(id);
    if (name != null) f.name = name;
    if (offset != null) f.offset = offset;
    if (enableAlert != null) f.enableAlert = enableAlert;
    if (alertThUpper != null) f.alertThUpper = alertThUpper;
    if (alertThLower != null) f.alertThLower = alertThLower;
    if (remark != null) f.remark = remark;
    if (drainageControl != null) f.drainageControl = drainageControl;
    notifyListeners();
  }

  String bulkDisplayMethod = '選択表示';
  int bulkWaterUpper = 0;
  int bulkWaterLower = 0;
  int bulkTempUpper = 0;
  int bulkTempLower = 0;
  bool bulkDrainageControl = false;

  void updateBulkSettings({
    required String displayMethod,
    required int waterUpper,
    required int waterLower,
    required int tempUpper,
    required int tempLower,
    required bool drainageControl,
  }) {
    bulkDisplayMethod = displayMethod;
    bulkWaterUpper = waterUpper;
    bulkWaterLower = waterLower;
    bulkTempUpper = tempUpper;
    bulkTempLower = tempLower;
    bulkDrainageControl = drainageControl;
    notifyListeners();
  }

  final Map<String, OpenCloseRequest> _openCloseRequests = {};

  bool get hasAnyOpenCloseRequest => _openCloseRequests.isNotEmpty;

  bool isOpenCloseRequested(String fieldId) =>
      _openCloseRequests.containsKey(fieldId);

  OpenCloseRequest? getOpenCloseRequest(String fieldId) =>
      _openCloseRequests[fieldId];

  void setOpenCloseRequests(Map<String, OpenCloseRequest> reqs) {
    _openCloseRequests
      ..clear()
      ..addAll(reqs);
    notifyListeners();
  }

  void clearOpenCloseRequests() {
    _openCloseRequests.clear();
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
      throw StateError('AppStateScope is not found in widget tree.');
    }
    return scope.notifier!;
  }
}

class OpenCloseRequest {
  OpenCloseRequest({required this.action, required this.scheduledAt});
  final String action;
  final DateTime scheduledAt;
}
