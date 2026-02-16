import 'package:flutter/material.dart';

import 'auth/auth_screens.dart';
import 'pages/home_screen.dart';

// 画面追加時の変更点をルーティング定義に集約し、main.dart の責務を減らす。
final Map<String, WidgetBuilder> appRoutes = {
  '/': (_) => const AuthStartScreen(),
  '/home': (_) => const HomeScreen(),
};
