// lib/auth_screens.dart

import 'package:flutter/material.dart';
import 'common_widgets.dart';

/// ====== 画面: 認証スタート（ログイン / 新規登録） ======
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
                  Navigator.pushReplacementNamed(context, '/home');
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
