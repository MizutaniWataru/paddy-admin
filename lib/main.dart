import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'paddy_add_map_screen.dart';
import 'data_model.dart';
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

const String kBaseUrl = String.fromEnvironment(
  'AMBERLOGIX_BASE_URL',
  defaultValue: 'https://dev.amberlogix.co.jp',
);

void main() {
  runApp(const AppRoot());
}

/// ====== App State（ダミー） ======
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

/// ====== Root ======
class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  final AppState state = AppState();

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF67C587); // PDFの薄緑っぽいボタン寄せ

    return AppStateScope(
      notifier: state,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('ja'),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ja')],
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: seed),
          useMaterial3: true,
          scaffoldBackgroundColor: Colors.white,
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),
          ),
        ),
        home: const AuthStartScreen(),
      ),
    );
  }
}

/// ====== Models ======
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

/// ====== Common Widgets ======
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

class ScreenPadding extends StatelessWidget {
  const ScreenPadding({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.all(16), child: child);
  }
}

/// ====== 画面: 認証スタート（ログイン / 新規登録） ======
/// PDF: 「ログイン」「新規登録」 :contentReference[oaicite:2]{index=2}
class AuthStartScreen extends StatelessWidget {
  const AuthStartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ScreenPadding(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PrimaryButton(
                  label: 'ログイン',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LoginRequestCodeScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),
                PrimaryButton(
                  label: '新規登録',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RegisterStartScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ====== 画面: ログイン（メール/電話 → 認証コード送信） ======
/// PDF: 「メールアドレスまたは電話番号」「認証コードを送信」 :contentReference[oaicite:3]{index=3}
class LoginRequestCodeScreen extends StatefulWidget {
  const LoginRequestCodeScreen({super.key});

  @override
  State<LoginRequestCodeScreen> createState() => _LoginRequestCodeScreenState();
}

class _LoginRequestCodeScreenState extends State<LoginRequestCodeScreen> {
  final ctrl = TextEditingController();

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: ScreenPadding(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('メールアドレスまたは電話番号'),
            const SizedBox(height: 8),
            TextField(controller: ctrl),
            const SizedBox(height: 12),
            PrimaryButton(
              label: '認証コードを送信',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const VerifyCodeScreen(nextIsHome: true),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// ====== 画面: 新規登録（メール/電話 → 次へ） ======
/// PDF: 「メールアドレス または 電話番号（SMS認証できるもの）」「次へ」 :contentReference[oaicite:4]{index=4}
class RegisterStartScreen extends StatefulWidget {
  const RegisterStartScreen({super.key});

  @override
  State<RegisterStartScreen> createState() => _RegisterStartScreenState();
}

class _RegisterStartScreenState extends State<RegisterStartScreen> {
  final ctrl = TextEditingController();

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: ScreenPadding(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('メールアドレス\nまたは\n電話番号（SMS認証できるもの）'),
            const SizedBox(height: 8),
            TextField(controller: ctrl),
            const SizedBox(height: 12),
            PrimaryButton(
              label: '次へ',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RegisterUserNameScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// ====== 画面: 新規登録（ユーザー名入力 → 送信） ======
/// PDF: 「ユーザー名を入力」「送信」 :contentReference[oaicite:5]{index=5}
class RegisterUserNameScreen extends StatefulWidget {
  const RegisterUserNameScreen({super.key});

  @override
  State<RegisterUserNameScreen> createState() => _RegisterUserNameScreenState();
}

class _RegisterUserNameScreenState extends State<RegisterUserNameScreen> {
  final ctrl = TextEditingController();

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: ScreenPadding(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('ユーザー名を入力'),
            const SizedBox(height: 8),
            TextField(controller: ctrl),
            const SizedBox(height: 12),
            PrimaryButton(
              label: '送信',
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const AuthStartScreen()),
                  (route) => false,
                );

                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('ユーザー登録しました（仮）')));
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// ====== 画面: 認証コード入力（送信 → 圃場一覧へ） ======
/// PDF: 「認証コード」「送信」 :contentReference[oaicite:6]{index=6}
class VerifyCodeScreen extends StatefulWidget {
  const VerifyCodeScreen({super.key, required this.nextIsHome});
  final bool nextIsHome;

  @override
  State<VerifyCodeScreen> createState() => _VerifyCodeScreenState();
}

class _VerifyCodeScreenState extends State<VerifyCodeScreen> {
  final ctrl = TextEditingController();

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: ScreenPadding(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('認証コード'),
            const SizedBox(height: 8),
            TextField(controller: ctrl, keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            PrimaryButton(
              label: '送信',
              onPressed: () {
                if (widget.nextIsHome) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                  );
                } else {
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// ====== 画面: 圃場一覧 ======
/// PDF: 「圃場一覧」「＋」「水位」「水温」「天気情報」「開閉依頼」 :contentReference[oaicite:7]{index=7}
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sync(showSnack: false);
    });
  }

  Future<void> _sync({required bool showSnack}) async {
    final state = AppStateScope.of(context);
    await state.syncDevicesAndLatest();

    if (!mounted) return;
    if (showSnack && state.syncError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(state.syncError!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AppSettingsScreen()),
            );
          },
        ),
        title: const Text('圃場一覧'),
        actions: [
          IconButton(
            icon: state.isSyncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: state.isSyncing ? null : () => _sync(showSnack: true),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final nav = Navigator.of(context);
              final selectedUuids = await Navigator.push<List<String>>(
                context,
                MaterialPageRoute(
                  builder: (_) => const PaddyAddFromMapScreen(),
                ),
              );
              if (!mounted) return;
              if (selectedUuids == null || selectedUuids.isEmpty) return;

              nav.push(
                MaterialPageRoute(
                  builder: (_) => FieldRegisterPlanScreen(
                    pref: '',
                    city: '',
                    fieldName: '圃場（地図追加）',
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyPageScreen()),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: PrimaryButton(
            label: '開閉依頼',
            onPressed: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('開閉依頼（仮）')));
            },
          ),
        ),
      ),
      body: AnimatedBuilder(
        animation: state,
        builder: (_, _) {
          return RefreshIndicator(
            onRefresh: () => _sync(showSnack: false),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              children: [
                _WeatherInfoCard(
                  onTap: () {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('天気情報（仮）')));
                  },
                ),
                const SizedBox(height: 10),

                // ★ ここが追加：圃場が0件なら空状態を表示
                if (state.fields.isEmpty)
                  _EmptyFieldsCard(
                    isSyncing: state.isSyncing,
                    errorText: state.syncError,
                    onRefresh: () => _sync(showSnack: true),
                    onAdd: () async {
                      final selectedUuids = await Navigator.push<List<String>>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PaddyAddFromMapScreen(),
                        ),
                      );
                      if (!context.mounted) return;
                      if (selectedUuids == null || selectedUuids.isEmpty) {
                        return;
                      }

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FieldRegisterPlanScreen(
                            pref: '',
                            city: '',
                            fieldName: '圃場（地図追加）',
                          ),
                        ),
                      );
                    },
                  )
                else
                  ...state.fields.map((f) => _FieldCard(field: f)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _WeatherInfoCard extends StatelessWidget {
  const _WeatherInfoCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: const Center(child: Text('天気情報')),
        onTap: onTap,
      ),
    );
  }
}

class _EmptyFieldsCard extends StatelessWidget {
  const _EmptyFieldsCard({
    required this.isSyncing,
    required this.errorText,
    required this.onRefresh,
    required this.onAdd,
  });

  final bool isSyncing;
  final String? errorText;
  final VoidCallback onRefresh;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.grass_outlined, size: 48),
            const SizedBox(height: 8),
            const Text(
              '圃場がありません',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              '右上の「＋」から追加するか、\n引っ張って更新してください。',
              textAlign: TextAlign.center,
            ),

            if (errorText != null) ...[
              const SizedBox(height: 10),
              Text(
                errorText!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],

            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isSyncing ? null : onRefresh,
                    icon: isSyncing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    label: Text(isSyncing ? '更新中…' : '更新'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add),
                    label: const Text('追加'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldCard extends StatelessWidget {
  const _FieldCard({required this.field});
  final FieldModel field;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FieldDetailScreen(fieldId: field.id),
            ),
          );
        },

        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 画像（前と同じ左側配置 + 少し大きく）
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 96,
                  height: 72,
                  child: (field.imageUrl != null && field.imageUrl!.isNotEmpty)
                      ? Image.network(
                          field.imageUrl!,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.black12,
                              child: const Center(
                                child: Icon(Icons.broken_image_outlined),
                              ),
                            );
                          },
                        )
                      : Container(
                          color: Colors.black12,
                          child: const Center(
                            child: Icon(Icons.image_outlined),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),

              // 右側（圃場名は今まで通りの出し方）
              Expanded(
                child: field.isPending
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            field.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(field.pendingText ?? '登録申請中'),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 左：圃場名（今まで通り）
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  field.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  ' ', // 余白（必要なければ消してOK）
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 10),

                          // 右：水位・水温（縦並び）
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(field.waterLevelText),
                              const SizedBox(height: 6),
                              Text(field.waterTempText),
                            ],
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ====== 画面: マイページ ======
/// PDF: 「マイページ」「プロフィール」「支払い履歴」「ログ」「変更」 :contentReference[oaicite:8]{index=8}
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

/// ====== 画面: 圃場登録（地図/都道府県/市区町村 → 次へ） ======
/// PDF: 「圃場登録」「都道府県 市区町村」「次へ」 :contentReference[oaicite:9]{index=9}
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
/// PDF: 「契約プラン」「登録申請」 :contentReference[oaicite:10]{index=10}
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
            const Spacer(),
            PrimaryButton(
              label: '登録申請',
              onPressed: () {
                state.addPendingField(
                  name: widget.fieldName,
                  pref: widget.pref,
                  city: widget.city,
                  plan: plan,
                );
                Navigator.popUntil(context, (r) => r.isFirst);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
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

/// ====== 画面: 圃場詳細（グラフ + 作業履歴 + 設定へ） ======
/// PDF: 「圃場A」「グラフ」「1日/3日/7日」「作業履歴」「設定」 :contentReference[oaicite:11]{index=11}
enum ChartDataType { waterLevel, temperature }

class FieldDetailScreen extends StatefulWidget {
  const FieldDetailScreen({super.key, required this.fieldId});
  final String fieldId;

  @override
  State<FieldDetailScreen> createState() => _FieldDetailScreenState();
}

class _FieldDetailScreenState extends State<FieldDetailScreen> {
  String range = '1日';

  ChartDataType _chartType = ChartDataType.waterLevel;

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 1));
  DateTime _endDate = DateTime.now();

  bool _isLoading = true;
  String? _error;

  List<FlSpot> _waterLevelSpots = [];
  List<FlSpot> _temperatureSpots = [];

  // zipは固定URLだったけど、後で差し替えやすいように一応定数化
  static const String _baseUrl = String.fromEnvironment(
    'AMBERLOGIX_BASE_URL',
    defaultValue: 'https://dev.amberlogix.co.jp',
  );

  @override
  void initState() {
    super.initState();
    _applyRange();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchDetailsData();
    });
  }

  void _applyRange() {
    final now = DateTime.now();
    final days = (range == '1日')
        ? 1
        : (range == '3日')
        ? 3
        : 7;
    _endDate = now;
    _startDate = now.subtract(Duration(days: days));
  }

  Future<void> _fetchDetailsData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final state = AppStateScope.of(context);
      final field = state.getFieldById(widget.fieldId);

      final fromDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(_startDate);
      final toDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(_endDate);

      final url =
          '$_baseUrl/app/paddy/get_device_data?padid=${field.id}&fromd=$fromDate&tod=$toDate';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        throw Exception('サーバーエラー: ${response.statusCode}');
      }

      final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));

      final newWater = <FlSpot>[];
      final newTemp = <FlSpot>[];

      for (final item in data) {
        final measuredDate = DateTime.parse(item['measured_date']);

        // zip同様：waterlevelはmm → cm
        final waterLevelMm = (item['waterlevel'] as num?)?.toDouble() ?? 0.0;
        final waterLevelCm = waterLevelMm / 10.0;

        final temperature = (item['temperature'] as num?)?.toDouble();

        newWater.add(
          FlSpot(measuredDate.millisecondsSinceEpoch.toDouble(), waterLevelCm),
        );

        if (temperature != null) {
          newTemp.add(
            FlSpot(measuredDate.millisecondsSinceEpoch.toDouble(), temperature),
          );
        }
      }

      if (!mounted) return;

      setState(() {
        _waterLevelSpots = newWater;
        _temperatureSpots = newTemp;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'データ取得に失敗しました: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  LineChartData _buildChartData(List<FlSpot> spots) {
    final cs = Theme.of(context).colorScheme;

    return LineChartData(
      gridData: const FlGridData(show: true),
      titlesData: const FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      lineTouchData: const LineTouchData(enabled: true),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: false,
          barWidth: 2,
          color: cs.primary,
          dotData: const FlDotData(show: false),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final field = state.getFieldById(widget.fieldId);

    final spots = (_chartType == ChartDataType.waterLevel)
        ? _waterLevelSpots
        : _temperatureSpots;

    return Scaffold(
      appBar: AppBar(
        title: Text(field.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FieldSettingsScreen(fieldId: field.id),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // ===== グラフ（PDFのUIそのまま）=====
          Row(
            children: [
              const Expanded(
                child: Text(
                  'グラフ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),

              // ついでに「水位/水温」切替（UIはほぼPDFのまま）
              PopupMenuButton<ChartDataType>(
                tooltip: '表示切替',
                initialValue: _chartType,
                onSelected: (v) => setState(() => _chartType = v),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: ChartDataType.waterLevel,
                    child: Text('水位'),
                  ),
                  PopupMenuItem(
                    value: ChartDataType.temperature,
                    child: Text('水温'),
                  ),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    _chartType == ChartDataType.waterLevel ? '水位 ▾' : '水温 ▾',
                  ),
                ),
              ),

              DropdownButton<String>(
                value: range,
                items: const [
                  DropdownMenuItem(value: '1日', child: Text('1日')),
                  DropdownMenuItem(value: '3日', child: Text('3日')),
                  DropdownMenuItem(value: '7日', child: Text('7日')),
                ],
                onChanged: (v) {
                  setState(() => range = v ?? '1日');
                  _applyRange();
                  _fetchDetailsData();
                },
              ),
            ],
          ),
          const SizedBox(height: 8),

          Container(
            height: 180,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(12),
            ),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : (_error != null)
                ? Center(child: Text(_error!))
                : (spots.isEmpty)
                ? const Center(child: Text('データがありません'))
                : Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: LineChart(_buildChartData(spots)),
                  ),
          ),

          const SizedBox(height: 16),

          // ===== 作業履歴（今まで通り）=====
          const Text('作業履歴', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (field.works.isEmpty)
            const Text('履歴がありません')
          else
            ...field.works.map((w) => _WorkCard(fieldId: field.id, work: w)),
        ],
      ),
    );
  }
}

class _WorkCard extends StatelessWidget {
  const _WorkCard({required this.fieldId, required this.work});
  final String fieldId;
  final WorkLog work;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  WorkDetailScreen(fieldId: fieldId, workId: work.id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.image_outlined),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${work.timeText}  ${work.actionText}  ${work.title}',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ====== 画面: 作業詳細（写真/コメント） ======
class WorkDetailScreen extends StatefulWidget {
  const WorkDetailScreen({
    super.key,
    required this.fieldId,
    required this.workId,
  });

  final String fieldId;
  final String workId;

  @override
  State<WorkDetailScreen> createState() => _WorkDetailScreenState();
}

class _WorkDetailScreenState extends State<WorkDetailScreen> {
  final ctrl = TextEditingController();

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final field = state.getFieldById(widget.fieldId);
    final work = field.works.firstWhere((w) => w.id == widget.workId);

    return Scaffold(
      appBar: AppBar(title: Text(work.title)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(child: Text('ステータス  ${work.status}')),
                Text('担当者  ${work.assignee}'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(child: Text('写真')),
            ),
          ),
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Align(alignment: Alignment.centerLeft, child: Text('コメント')),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: work.comments.length,
              itemBuilder: (_, i) {
                final msg = work.comments[i];
                final isMine = i.isOdd;
                return Align(
                  alignment: isMine
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(10),
                    constraints: const BoxConstraints(maxWidth: 280),
                    decoration: BoxDecoration(
                      color: isMine
                          ? Colors.teal.withValues(alpha: 0.15)
                          : Colors.black12,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(msg),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(child: TextField(controller: ctrl)),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: () {
                      final text = ctrl.text.trim();
                      if (text.isEmpty) return;
                      setState(() {
                        work.comments.add(text);
                        ctrl.clear();
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ====== 画面: 圃場設定 ======
class FieldSettingsScreen extends StatefulWidget {
  const FieldSettingsScreen({super.key, required this.fieldId});
  final String fieldId;

  @override
  State<FieldSettingsScreen> createState() => _FieldSettingsScreenState();
}

class _FieldSettingsScreenState extends State<FieldSettingsScreen> {
  final nameCtrl = TextEditingController();
  final currentCtrl = TextEditingController(text: '（仮）');

  String plan = 'ベーシック';
  String setMethod = '一括'; // 一括 / 個別
  String displayMethod = '相対値'; // 相対値 / 絶対値

  bool _loading = true;
  String? _loadError;

  int _serverOffset = 0;
  bool _serverEnableAlert = false;

  final waterUpperCtrl = TextEditingController();
  final waterLowerCtrl = TextEditingController();
  final tempUpperCtrl = TextEditingController();
  final tempLowerCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFromServer();
    });
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    currentCtrl.dispose();
    waterUpperCtrl.dispose();
    waterLowerCtrl.dispose();
    tempUpperCtrl.dispose();
    tempLowerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final field = state.getFieldById(widget.fieldId);

    plan = field.plan ?? plan;

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_loadError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _loadError!,
                style: const TextStyle(color: Colors.red),
              ),
            ),

          const SizedBox(height: 12),

          TextField(
            controller: nameCtrl,
            decoration: const InputDecoration(labelText: '圃場名'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: currentCtrl,
            decoration: const InputDecoration(labelText: '現在水位'),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: plan,
            decoration: const InputDecoration(labelText: '契約プラン'),
            items: const [
              DropdownMenuItem(value: 'ベーシック', child: Text('ベーシック')),
              DropdownMenuItem(value: 'スタンダード', child: Text('スタンダード')),
            ],
            onChanged: (v) => setState(() => plan = v ?? plan),
          ),
          const SizedBox(height: 12),
          const Text('設定方法'),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: '一括', label: Text('一括')),
              ButtonSegment(value: '個別', label: Text('個別')),
            ],
            selected: {setMethod},
            onSelectionChanged: (newSelection) {
              setState(() => setMethod = newSelection.first);
            },
          ),
          const SizedBox(height: 8),
          const Text('水位表示方法'),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: '相対値', label: Text('相対値')),
              ButtonSegment(value: '絶対値', label: Text('絶対値')),
            ],
            selected: {displayMethod},
            onSelectionChanged: (newSelection) {
              setState(() => displayMethod = newSelection.first);
            },
          ),

          const SizedBox(height: 10),
          TextField(
            controller: waterUpperCtrl,
            decoration: const InputDecoration(labelText: '水位上限'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: waterLowerCtrl,
            decoration: const InputDecoration(labelText: '水位下限'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: tempUpperCtrl,
            decoration: const InputDecoration(labelText: '水温上限'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: tempLowerCtrl,
            decoration: const InputDecoration(labelText: '水温下限'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: '変更',
            onPressed: _loading
                ? null
                : () async {
                    final scaffold = ScaffoldMessenger.of(context);
                    final appState = AppStateScope.of(context);
                    final field = appState.getFieldById(widget.fieldId);

                    final upper =
                        int.tryParse(waterUpperCtrl.text) ?? field.alertThUpper;
                    final lower =
                        int.tryParse(waterLowerCtrl.text) ?? field.alertThLower;

                    final payload = {
                      'padid': widget.fieldId,
                      'paddyname': nameCtrl.text.trim().isEmpty
                          ? field.name
                          : nameCtrl.text.trim(),
                      'offset': _serverOffset,
                      'enable_alert': _serverEnableAlert ? 1 : 0,
                      'alert_th_upper': upper,
                      'alert_th_lower': lower,
                    };

                    try {
                      final res = await http.post(
                        Uri.parse('$kBaseUrl/app/paddy/update_device'),
                        headers: {'Content-Type': 'application/json'},
                        body: jsonEncode(payload),
                      );

                      if (res.statusCode != 200) {
                        throw Exception('update_device: ${res.statusCode}');
                      }

                      field.name = payload['paddyname'] as String;
                      field.alertThUpper = upper;
                      field.alertThLower = lower;

                      appState.updateField(
                        widget.fieldId,
                        name: payload['paddyname'] as String,
                        alertThUpper: upper,
                        alertThLower: lower,
                      );

                      scaffold.showSnackBar(
                        const SnackBar(content: Text('変更しました')),
                      );
                    } catch (e) {
                      scaffold.showSnackBar(
                        SnackBar(content: Text('保存に失敗: $e')),
                      );
                    }
                  },
          ),
        ],
      ),
    );
  }

  Future<void> _loadFromServer() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final res = await http.get(Uri.parse('$kBaseUrl/app/paddy/get_devices'));
      if (!mounted) return;
      if (res.statusCode != 200) {
        throw Exception('get_devices: ${res.statusCode}');
      }

      final List<dynamic> list = json.decode(utf8.decode(res.bodyBytes));

      Map<String, dynamic>? found;
      for (final it in list) {
        if (it is Map<String, dynamic> &&
            it['padid'].toString() == widget.fieldId) {
          found = it;
          break;
        }
      }
      if (found == null) {
        throw Exception('対象の圃場が見つかりません (padid=${widget.fieldId})');
      }

      final apiField = PaddyField.fromJson(found);

      // ローカルStateも更新（一覧と整合させる）
      final state = AppStateScope.of(context);
      final field = state.getFieldById(widget.fieldId);

      field.name = apiField.name;
      field.offset = apiField.offset;
      field.enableAlert = apiField.enableAlert;
      field.alertThUpper = apiField.alertThUpper;
      field.alertThLower = apiField.alertThLower;

      state.updateField(
        widget.fieldId,
        name: apiField.name,
        offset: apiField.offset,
        enableAlert: apiField.enableAlert,
        alertThUpper: apiField.alertThUpper,
        alertThLower: apiField.alertThLower,
      );

      // UIに反映（表示項目は今のまま）
      nameCtrl.text = apiField.name;
      currentCtrl.text = field.waterLevelText; // 現在水位は一覧で持ってる表示を流用
      waterUpperCtrl.text = apiField.alertThUpper.toString();
      waterLowerCtrl.text = apiField.alertThLower.toString();

      // UIに出さないけど保存で使う
      _serverOffset = apiField.offset;
      _serverEnableAlert = apiField.enableAlert;

      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadError = '設定の取得に失敗: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }
}

/// ====== 画面: アプリ設定（ホームの歯車の仮） ======
class AppSettingsScreen extends StatelessWidget {
  const AppSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: const ScreenPadding(child: Text('ホーム左上の歯車（仮）')),
    );
  }
}
