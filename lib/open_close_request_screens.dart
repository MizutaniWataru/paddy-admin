import 'package:flutter/material.dart';
import 'app_state.dart';
import 'common_widgets.dart';
import 'field_models.dart';

const _kActions = <String>['給水開ける', '給水閉じる', '排水開ける', '排水閉じる'];

class _SelectedFieldAction {
  _SelectedFieldAction({required this.fieldId, required this.action});
  final String fieldId;
  final String action;
}

/// ====== 画面: 圃場選択 ======
class OpenCloseRequestFieldSelectScreen extends StatefulWidget {
  const OpenCloseRequestFieldSelectScreen({super.key});

  @override
  State<OpenCloseRequestFieldSelectScreen> createState() =>
      _OpenCloseRequestFieldSelectScreenState();
}

class _OpenCloseRequestFieldSelectScreenState
    extends State<OpenCloseRequestFieldSelectScreen> {
  final Set<String> _selected = {};
  final Map<String, String> _actionById = {}; // fieldId -> action

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = AppStateScope.of(context);

    // 初期値（未設定なら「給水開ける」）
    for (final f in state.fields) {
      _actionById.putIfAbsent(f.id, () => _kActions.first);
    }
  }

  void _recommendSelect() {
    final state = AppStateScope.of(context);
    setState(() {
      _selected
        ..clear()
        ..addAll(state.fields.where((f) => !f.isPending).map((f) => f.id));
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    final fields = state.fields;
    final canNext = _selected.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('圃場選択')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Align(
            alignment: Alignment.center,
            child: FilledButton.tonal(
              onPressed: fields.isEmpty ? null : _recommendSelect,
              child: const Text('おすすめ選択'),
            ),
          ),
          const SizedBox(height: 12),

          for (final f in fields)
            _FieldPickRow(
              field: f,
              selected: _selected.contains(f.id),
              action: _actionById[f.id] ?? _kActions.first,
              onToggle: f.isPending
                  ? null
                  : (v) {
                      setState(() {
                        if (v) {
                          _selected.add(f.id);
                        } else {
                          _selected.remove(f.id);
                        }
                      });
                    },
              onActionChanged: f.isPending
                  ? null
                  : (v) {
                      if (v == null) return;
                      setState(() => _actionById[f.id] = v);
                    },
            ),

          const SizedBox(height: 12),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: PrimaryButton(
            label: '次へ',
            onPressed: canNext
                ? () {
                    final selected = _selected
                        .map(
                          (id) => _SelectedFieldAction(
                            fieldId: id,
                            action: _actionById[id] ?? _kActions.first,
                          ),
                        )
                        .toList();

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            OpenCloseRequestTimeScreen(selected: selected),
                      ),
                    );
                  }
                : null,
          ),
        ),
      ),
    );
  }
}

class _FieldPickRow extends StatelessWidget {
  const _FieldPickRow({
    required this.field,
    required this.selected,
    required this.action,
    required this.onToggle,
    required this.onActionChanged,
  });

  final FieldModel field;
  final bool selected;
  final String action;
  final ValueChanged<bool>? onToggle;
  final ValueChanged<String?>? onActionChanged;

  @override
  Widget build(BuildContext context) {
    final enabled = onToggle != null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Checkbox(
              value: selected,
              onChanged: enabled ? (v) => onToggle?.call(v ?? false) : null,
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 72,
                height: 54,
                child: (field.imageUrl != null && field.imageUrl!.isNotEmpty)
                    ? Image.network(field.imageUrl!, fit: BoxFit.cover)
                    : Container(
                        color: Colors.black12,
                        child: const Icon(Icons.image_outlined),
                      ),
              ),
            ),
            const SizedBox(width: 10),

            Expanded(
              child: Text(
                field.name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: enabled ? null : Colors.black38,
                ),
              ),
            ),

            const SizedBox(width: 10),

            SizedBox(
              width: 150,
              child: DropdownButtonFormField<String>(
                initialValue: action,
                isExpanded: true,
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                ),
                items: _kActions.map((a) {
                  // 排水制御が無い圃場なら、排水系は選べないようにしておく（見た目は出す）
                  final isDrain = a.startsWith('排水');
                  final itemEnabled =
                      !isDrain || (field.drainageControl == true);
                  return DropdownMenuItem(
                    value: a,
                    enabled: itemEnabled,
                    child: Text(
                      a,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: itemEnabled ? null : Colors.black38,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: enabled ? onActionChanged : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ====== 画面: 時刻設定 ======
class OpenCloseRequestTimeScreen extends StatefulWidget {
  const OpenCloseRequestTimeScreen({super.key, required this.selected});
  final List<_SelectedFieldAction> selected;

  @override
  State<OpenCloseRequestTimeScreen> createState() =>
      _OpenCloseRequestTimeScreenState();
}

class _OpenCloseRequestTimeScreenState
    extends State<OpenCloseRequestTimeScreen> {
  final Map<String, DateTime> _dtById = {}; // fieldId -> datetime

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final now = DateTime.now().add(const Duration(minutes: 5));
    for (final s in widget.selected) {
      _dtById.putIfAbsent(s.fieldId, () => now);
    }
  }

  void _recommendTime() {
    final dt = DateTime.now().add(const Duration(minutes: 5));
    setState(() {
      for (final s in widget.selected) {
        _dtById[s.fieldId] = dt;
      }
    });
  }

  Future<void> _pickDateTime(String fieldId) async {
    final initial = _dtById[fieldId] ?? DateTime.now();

    final d = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (!mounted || d == null) return;

    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (!mounted || t == null) return;

    setState(() {
      _dtById[fieldId] = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    });
  }

  String _fmt(BuildContext context, DateTime dt) {
    final loc = MaterialLocalizations.of(context);
    final date = loc.formatShortDate(dt);
    final time = loc.formatTimeOfDay(
      TimeOfDay.fromDateTime(dt),
      alwaysUse24HourFormat: true,
    );
    return '$date $time';
  }

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('時刻設定')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Align(
            alignment: Alignment.center,
            child: FilledButton.tonal(
              onPressed: _recommendTime,
              child: const Text('おすすめ設定'),
            ),
          ),
          const SizedBox(height: 12),

          for (final s in widget.selected)
            Builder(
              builder: (context) {
                final f = state.getFieldById(s.fieldId);
                final dt = _dtById[s.fieldId] ?? DateTime.now();
                return Card(
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 56,
                        height: 42,
                        child: (f.imageUrl != null && f.imageUrl!.isNotEmpty)
                            ? Image.network(f.imageUrl!, fit: BoxFit.cover)
                            : Container(
                                color: Colors.black12,
                                child: const Icon(Icons.image_outlined),
                              ),
                      ),
                    ),
                    title: Text(
                      f.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('${s.action}  /  ${_fmt(context, dt)}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.access_time),
                      onPressed: () => _pickDateTime(s.fieldId),
                    ),
                  ),
                );
              },
            ),

          const SizedBox(height: 12),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: PrimaryButton(
            label: '依頼送信',
            onPressed: () {
              // AppStateへ反映（仮）
              final reqs = <String, OpenCloseRequest>{};
              for (final s in widget.selected) {
                reqs[s.fieldId] = OpenCloseRequest(
                  action: s.action,
                  scheduledAt: _dtById[s.fieldId] ?? DateTime.now(),
                );
              }
              state.setOpenCloseRequests(reqs);

              // ホームへ戻る
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/home', (r) => false);
            },
          ),
        ),
      ),
    );
  }
}
