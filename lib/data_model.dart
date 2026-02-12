import 'package:latlong2/latlong.dart';

class FieldData {
  final String id;
  final String name;
  final String imageUrl;
  final String? time;
  final int? temperature;
  final double? waterLevel;
  final LatLng location;
  final int offset;
  final bool enableAlert;
  final int alertThUpper;
  final int alertThLower;

  FieldData({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.time,
    this.temperature,
    required this.waterLevel,
    required this.location,
    required this.offset,
    required this.enableAlert,
    required this.alertThUpper,
    required this.alertThLower,
  });

  factory FieldData.fromJson(Map<String, dynamic> json) {
    const String baseUrl = 'https://';

    final dynamic rawID = json['field_id'] ?? json['padid'];
    final dynamic rawName = json['field_name'] ?? json['paddyname'];
    final String img = (json['img'] ?? '').toString();

    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    int? parseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString());
    }

    final waterLevel = parseDouble(json['waterlevel'] ?? json['water_level']);
    final temperature =
        parseInt(json['temperature'] ?? json['water_temperature']);

    return FieldData(
      id: (rawID ?? '').toString(),
      name: (rawName ?? '').toString(),
      imageUrl: img.isEmpty ? '' : '$baseUrl$img',
      location: LatLng(
        (json['lat'] as num?)?.toDouble() ?? 0,
        (json['lon'] as num?)?.toDouble() ?? 0,
      ),
      offset: (json['offset'] as num?)?.toInt() ?? 0,
      enableAlert: (json['enable_alert'] is int)
          ? (json['enable_alert'] as int) == 1
          : (json['enable_alert'] == true),
      alertThUpper: (json['alert_th_upper'] as num?)?.toInt() ?? 0,
      alertThLower: (json['alert_th_lower'] as num?)?.toInt() ?? 0,
      time: null,
      temperature: temperature,
      waterLevel: waterLevel,
    );
  }

  FieldData copyWith({
    String? id,
    String? name,
    String? imageUrl,
    String? time,
    int? temperature,
    double? waterLevel,
    LatLng? location,
    int? offset,
    bool? enableAlert,
    int? alertThUpper,
    int? alertThLower,
  }) {
    return FieldData(
      id: id ?? this.id,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      time: time ?? this.time,
      temperature: temperature ?? this.temperature,
      waterLevel: waterLevel ?? this.waterLevel,
      location: location ?? this.location,
      offset: offset ?? this.offset,
      enableAlert: enableAlert ?? this.enableAlert,
      alertThUpper: alertThUpper ?? this.alertThUpper,
      alertThLower: alertThLower ?? this.alertThLower,
    );
  }
}
