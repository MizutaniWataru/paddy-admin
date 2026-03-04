class AreaModel {
  AreaModel({
    required this.id,
    required this.name,
    required this.fieldCount,
    this.weatherCode,
    this.tempC,
    this.rain12hMm,
  });

  final int id;
  final String name;
  final int fieldCount;
  final int? weatherCode;
  final double? tempC;
  final double? rain12hMm;

  factory AreaModel.fromJson(Map<String, dynamic> json) {
    int? parseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value.toString());
    }

    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    return AreaModel(
      id: parseInt(json['area_id']) ?? 0,
      name: (json['area_name'] ?? '').toString(),
      fieldCount: parseInt(json['field_count']) ?? 0,
      weatherCode: parseInt(json['area_weather']),
      tempC: parseDouble(json['area_temp']),
      rain12hMm: parseDouble(json['area_12rain']),
    );
  }
}
