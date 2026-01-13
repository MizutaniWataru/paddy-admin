// lib/field_models.dart
class FieldModel {
  FieldModel({
    required this.id,
    required this.name,
    required this.waterLevelText,
    required this.waterTempText,
    required this.isPending,
    required this.works,
    this.imageUrl,
    this.pendingText,
    this.pref,
    this.city,
    this.plan,

    this.remark,
    this.drainageControl = false,

    this.offset = 0,
    this.enableAlert = false,
    this.alertThUpper = 0,
    this.alertThLower = 0,
  });

  final String id;
  String name;

  String waterLevelText;
  String waterTempText;

  bool isPending;
  String? pendingText;

  String? imageUrl;

  String? pref;
  String? city;
  String? plan;

  String? remark;
  bool drainageControl;

  int offset;
  bool enableAlert;
  int alertThUpper;
  int alertThLower;

  final List<WorkLog> works;
}

class WorkLog {
  WorkLog({
    required this.id,
    required this.title,
    required this.timeText,
    required this.actionText,
    required this.status,
    required this.assignee,
    required this.comments,
  });

  final String id;
  final String title;
  final String timeText;
  final String actionText;
  final String status;
  final String assignee;
  final List<String> comments;
}
