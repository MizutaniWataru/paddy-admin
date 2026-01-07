import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_state.dart';
import 'auth_screens.dart';
import 'home_screen.dart';

void main() {
  runApp(const AppRoot());
}

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  final AppState state = AppState();

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF67C587);

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
        routes: {
          '/': (_) => const AuthStartScreen(),
          '/home': (_) => const HomeScreen(),
        },
      ),
    );
  }
}

/// ====== 画面: 圃場詳細（グラフ + 作業履歴 + 設定へ） ======
/// PDF: 「圃場A」「グラフ」「1日/3日/7日」「作業履歴」「設定」 :contentReference[oaicite:11]{index=11}
enum ChartDataType { waterLevel, temperature }
