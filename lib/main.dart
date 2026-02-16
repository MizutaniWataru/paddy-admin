import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';

import 'module/app_state.dart';
import 'router.dart';

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
          textTheme: GoogleFonts.notoSansJpTextTheme(),
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),
          ),
        ),
        routes: appRoutes,
      ),
    );
  }
}
