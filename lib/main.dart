import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'paddy_add_map_screen.dart';

void main() {
  runApp(const AppRoot());
}

/// ====== App State（いったんダミー。後でAPIやDBに差し替え） ======
class AppState extends ChangeNotifier {
  final List<FieldModel> fields = [
    FieldModel(
      id: 'a',
      name: '圃場A',
      waterLevelText: '水位 12cm',
      waterTempText: '水温 18℃',
      isPending: false,
      works: [
        WorkLog(
          id: 'w1',
          title: '作業A',
          timeText: '00時00分',
          actionText: '給水開',
          status: '完了',
          assignee: '○○××',
          comments: ['了解です', '写真確認しました'],
        ),
      ],
    ),
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

  FieldModel getFieldById(String id) => fields.firstWhere((f) => f.id == id);
}

class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({
    super.key,
    required AppState notifier,
    required Widget child,
  }) : super(notifier: notifier, child: child);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    if (scope == null || scope.notifier == null) {
      throw StateError('AppStateScope が見つからないよ');
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
    this.pendingText,
    this.pref,
    this.city,
    this.plan,
  });

  final String id;
  String name;

  String waterLevelText;
  String waterTempText;

  bool isPending;
  String? pendingText;

  String? pref;
  String? city;
  String? plan;

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
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
            icon: const Icon(Icons.add),
            onPressed: () async {
              final selectedUuids = await Navigator.push<List<String>>(
                context,
                MaterialPageRoute(
                  builder: (_) => const PaddyAddFromMapScreen(),
                ),
              );
              if (!context.mounted) return;
              if (selectedUuids == null || selectedUuids.isEmpty) return;

              // いったん「次へ（契約プラン）」へ流す
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
        builder: (_, __) {
          return ListView(
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
              ...state.fields.map((f) => _FieldCard(field: f)),
            ],
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
              Container(
                width: 96,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.image_outlined),
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
class FieldDetailScreen extends StatefulWidget {
  const FieldDetailScreen({super.key, required this.fieldId});
  final String fieldId;

  @override
  State<FieldDetailScreen> createState() => _FieldDetailScreenState();
}

class _FieldDetailScreenState extends State<FieldDetailScreen> {
  String range = '1日';

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);
    final field = state.getFieldById(widget.fieldId);

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
          Row(
            children: [
              const Expanded(
                child: Text(
                  'グラフ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DropdownButton<String>(
                value: range,
                items: const [
                  DropdownMenuItem(value: '1日', child: Text('1日')),
                  DropdownMenuItem(value: '3日', child: Text('3日')),
                  DropdownMenuItem(value: '7日', child: Text('7日')),
                ],
                onChanged: (v) => setState(() => range = v ?? '1日'),
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
            child: Center(child: Text('グラフ（$range） ※仮')),
          ),
          const SizedBox(height: 16),
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
                          ? Colors.teal.withOpacity(0.15)
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
/// PDF: 「圃場名」「相対値/絶対値」「設定方法（一括/個別）」「水位上限/下限」「水温上限/下限」「契約プラン」「変更」 :contentReference[oaicite:12]{index=12}
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

  final waterUpperCtrl = TextEditingController();
  final waterLowerCtrl = TextEditingController();
  final tempUpperCtrl = TextEditingController();
  final tempLowerCtrl = TextEditingController();

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

    nameCtrl.text = nameCtrl.text.isEmpty ? field.name : nameCtrl.text;
    plan = field.plan ?? plan;

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
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
            value: plan,
            decoration: const InputDecoration(labelText: '契約プラン'),
            items: const [
              DropdownMenuItem(value: 'ベーシック', child: Text('ベーシック')),
              DropdownMenuItem(value: 'スタンダード', child: Text('スタンダード')),
              DropdownMenuItem(value: 'プレミアム', child: Text('プレミアム')),
            ],
            onChanged: (v) => setState(() => plan = v ?? plan),
          ),
          const SizedBox(height: 12),
          const Text('設定方法'),
          RadioListTile<String>(
            value: '一括',
            groupValue: setMethod,
            onChanged: (v) => setState(() => setMethod = v ?? '一括'),
            title: const Text('一括'),
          ),
          RadioListTile<String>(
            value: '個別',
            groupValue: setMethod,
            onChanged: (v) => setState(() => setMethod = v ?? '個別'),
            title: const Text('個別'),
          ),
          const SizedBox(height: 8),
          const Text('水位表示方法'),
          RadioListTile<String>(
            value: '相対値',
            groupValue: displayMethod,
            onChanged: (v) => setState(() => displayMethod = v ?? '相対値'),
            title: const Text('相対値'),
          ),
          RadioListTile<String>(
            value: '絶対値',
            groupValue: displayMethod,
            onChanged: (v) => setState(() => displayMethod = v ?? '絶対値'),
            title: const Text('絶対値'),
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
            onPressed: () {
              setState(() {
                field.name = nameCtrl.text.trim().isEmpty
                    ? field.name
                    : nameCtrl.text.trim();
                field.plan = plan;
              });
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('変更しました（仮）')));
            },
          ),
        ],
      ),
    );
  }
}

/// ====== 画面: アプリ設定（ホームの歯車の仮） ======
class AppSettingsScreen extends StatelessWidget {
  const AppSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: const ScreenPadding(
        child: Text('ホーム左上の歯車（仮）\n※PDFには詳細項目がないので、後で仕様が決まったら追加しよ。'),
      ),
    );
  }
}
