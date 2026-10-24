import 'package:flutter/material.dart';
import 'package:ridey_app/design/ridey_theme.dart';
import 'package:ridey_app/features/habits/lookup_habits.dart';
import 'package:ridey_app/features/notifications/habit_notifier.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({
    super.key,
    this.store,
    this.habits,
    this.setEnabled,
  });

  final HabitNotificationStore? store;
  final LookupHabitStore? habits;
  final Future<bool> Function(bool enabled)? setEnabled;

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  late final HabitNotificationStore _store;
  late final LookupHabitStore _habits;
  late Future<void> _ready;
  var _enabled = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? HabitNotificationStore();
    _habits = widget.habits ?? LookupHabitStore();
    _ready = _load();
  }

  Future<void> _load() async {
    _enabled = await _store.isEnabled();
  }

  Future<void> _toggle(bool value) async {
    final next = await (widget.setEnabled ?? setHabitNotificationsEnabled)(
      value,
    );
    if (!mounted) return;
    setState(() {
      _enabled = next;
      _message = value && !next ? '알림 권한이 없어 켜지지 않았어요.' : null;
    });
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('조회 기록을 지울까요?'),
        content: const Text('알림이 참고하는 최근 14일 기록도 함께 지워져요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('지우기'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _habits.clear();
    if (!mounted) return;
    setState(() => _message = '조회 기록을 지웠어요.');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('알림')),
      body: FutureBuilder<void>(
        future: _ready,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
            children: [
              Text(
                '자주 확인하던 시간 15분 전부터, 그 근처의 고장 의심 자전거가 있을 때만 알려 드려요. 하루 한 번이고, 끄면 보내지 않아요.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: context.ridey.muted,
                ),
              ),
              const SizedBox(height: 20),
              Card(
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  title: const Text('습관 알림'),
                  subtitle: Text(_enabled ? '켜져 있어요' : '꺼져 있어요'),
                  value: _enabled,
                  onChanged: _toggle,
                ),
              ),
              if (_message != null) ...[
                const SizedBox(height: 16),
                Text(
                  _message!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: context.ridey.muted,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              OutlinedButton(onPressed: _clear, child: const Text('기록 지우기')),
            ],
          );
        },
      ),
    );
  }
}
