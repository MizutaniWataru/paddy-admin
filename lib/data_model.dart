import 'package:latlong2/latlong.dart';

// カード1枚分のデータをまとめるためのクラス
class PaddyField {
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

  PaddyField({
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

  factory PaddyField.fromJson(Map<String, dynamic> json) {
    // APIの画像パスはドメイン名を含まないので、ここでくっつける
    const String baseUrl = 'https://';

    return PaddyField(
      id: json['padid'].toString(),
      name: json['paddyname'],
      imageUrl: baseUrl + (json['img'] ?? ''), // もしimgがnullなら空文字に
      location: LatLng(
        (json['lat'] as num).toDouble(), // 安全に数値変換
        (json['lon'] as num).toDouble(),
      ),
      offset: json['offset'],
      enableAlert: (json['enable_alert'] is int)
          ? (json['enable_alert'] as int) == 1
          : (json['enable_alert'] == true),
      alertThUpper: json['alert_th_upper'],
      alertThLower: json['alert_th_lower'],
      // APIには時間や温度のデータがないので、ダミーデータ用にnullを入れておく
      time: null,
      temperature: null,
      waterLevel: null,
    );
  }

  PaddyField copyWith({
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
    return PaddyField(
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

// 表示したいダミーデータのリスト
// final List<PaddyField> dummyPaddyFields = [
//   PaddyField(
//     id: '1',
//     name: '水田1',
//     imageUrl: 'https://picsum.photos/seed/7/300/200',
//     time: '11:42',
//     temperature: 28.3,
//     waterLevel: 7.8,
//     location: LatLng(35.99472, 138.24639),
//   ),
//   PaddyField(
//     id: '2',
//     name: '水田2',
//     imageUrl: 'https://picsum.photos/seed/8/300/200',
//     time: '11:43',
//     temperature: 25.6,
//     waterLevel: 6.3,
//     location: LatLng(35.99472, 138.24649),
//   ),
//   PaddyField(
//     id: '3',
//     name: '水田3',
//     imageUrl: 'https://picsum.photos/seed/3/300/200',
//     time: '11:39',
//     temperature: 0.0,
//     waterLevel: 5.6,
//     location: LatLng(35.99472, 138.24659),
//   ), // 温度データなしの例
//   PaddyField(
//     id: '4',
//     name: '水田4',
//     imageUrl: 'https://picsum.photos/seed/4/300/200',
//     time: '11:42',
//     temperature: 0.0,
//     waterLevel: 14.1,
//     location: LatLng(35.99472, 138.24669),
//   ),
//   PaddyField(
//     id: '5',
//     name: '水田5',
//     imageUrl: 'https://picsum.photos/seed/5/300/200',
//     time: '11:48',
//     temperature: 0.0,
//     waterLevel: 6.7,
//     location: LatLng(35.99472, 138.24679),
//   ),
//   PaddyField(
//     id: '6',
//     name: '水田6',
//     imageUrl: 'https://picsum.photos/seed/6/300/200',
//     time: '11:47',
//     temperature: 0.0,
//     waterLevel: 6.4,
//     location: LatLng(35.99472, 138.24689),
//   ),
//   PaddyField(
//     id: '7',
//     name: '水田7',
//     imageUrl: 'https://picsum.photos/seed/9/300/200',
//     time: '11:47',
//     temperature: 0.0,
//     waterLevel: 6.4,
//     location: LatLng(35.99472, 138.24699),
//   ),
//   PaddyField(
//     id: '8',
//     name: '水田8',
//     imageUrl: 'https://picsum.photos/seed/10/300/200',
//     time: '11:47',
//     temperature: 0.0,
//     waterLevel: 6.4,
//     location: LatLng(35.99472, 138.24709),
//   ),
// ];
