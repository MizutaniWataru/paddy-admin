import 'package:flutter/material.dart';
import 'common_widgets.dart';
import 'app_state.dart';
import 'paddy_add_map_screen.dart';
import 'field_models.dart';
import 'field_register_screens.dart';
import 'my_page_screen.dart';
import 'field_detail_screen.dart';
import 'open_close_request_screens.dart';
import 'home_settings_screen.dart';

/// ====== 画面: 圃場一覧 ======
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
              MaterialPageRoute(builder: (_) => const HomeBulkSettingsScreen()),
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
          child: AnimatedBuilder(
            animation: state,
            builder: (_, _) {
              if (state.hasAnyOpenCloseRequest) {
                return Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: () => state.clearOpenCloseRequests(),
                        child: const Text('依頼中止'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: PrimaryButton(
                        label: '開閉依頼',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const OpenCloseRequestFieldSelectScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              }

              return PrimaryButton(
                label: '開閉依頼',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const OpenCloseRequestFieldSelectScreen(),
                    ),
                  );
                },
              );
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
                const _WeatherInfoStrip(),

                const SizedBox(height: 10),

                if (!state.hasLoadedOnce)
                  const _LoadingFieldsCard()
                else if (state.fields.isEmpty)
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
                  ...state.fields.map(
                    (f) => _FieldCard(
                      field: f,
                      isRequesting: state.isOpenCloseRequested(f.id),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _WeatherInfoStrip extends StatelessWidget {
  const _WeatherInfoStrip();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: const [
            Expanded(
              child: _WeatherMetric(
                icon: Icons.wb_sunny_outlined,
                iconColor: Color(0xFFF4C542),
                title: '天気',
                value: '晴れ',
              ),
            ),
            _WeatherDivider(),
            Expanded(
              child: _WeatherMetric(
                icon: Icons.thermostat_outlined,
                iconColor: Color(0xFFE53935),
                title: '気温',
                value: '7℃',
              ),
            ),
            _WeatherDivider(),
            Expanded(
              flex: 2,
              child: _WeatherMetric(
                icon: Icons.water_drop_outlined,
                iconColor: Color(0xFF1E88E5),
                title: '12時間予測降水量',
                value: '2mm',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeatherDivider extends StatelessWidget {
  const _WeatherDivider();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 1,
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: cs.outlineVariant,
    );
  }
}

class _WeatherMetric extends StatelessWidget {
  const _WeatherMetric({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: iconColor),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value, // ダミー値
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
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
            const Text('圃場または更新を行ってください。', textAlign: TextAlign.center),

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
  const _FieldCard({required this.field, required this.isRequesting});
  final FieldModel field;
  final bool isRequesting;

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
                                const Text(' ', style: TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),

                          const SizedBox(width: 10),

                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(field.waterLevelText),
                              const SizedBox(height: 6),
                              Text(field.waterTempText),
                              if (isRequesting) ...[
                                const SizedBox(height: 6),
                                const Text(
                                  '作業依頼中',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
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

class _LoadingFieldsCard extends StatelessWidget {
  const _LoadingFieldsCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: const [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('読み込み中…'),
          ],
        ),
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
      body: const ScreenPadding(child: Text('ホーム左上の歯車（仮）')),
    );
  }
}
