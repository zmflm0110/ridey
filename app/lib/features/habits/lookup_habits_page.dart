import 'package:flutter/material.dart';
import 'package:ridey_app/design/ridey_theme.dart';
import 'package:ridey_app/features/habits/lookup_habits.dart';

class LookupHabitsPage extends StatefulWidget {
  const LookupHabitsPage({super.key, this.store});

  final LookupHabitStore? store;

  @override
  State<LookupHabitsPage> createState() => _LookupHabitsPageState();
}

class _LookupHabitsPageState extends State<LookupHabitsPage> {
  late final LookupHabitStore _store;
  late Future<List<LookupEvent>> _events;

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? LookupHabitStore();
    _events = _store.load();
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('조회 기록을 지울까요?'),
        content: const Text('이 폰에 남은 최근 14일 기록을 지워요. 다시 되돌릴 수 없어요.'),
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
    await _store.clear();
    if (!mounted) return;
    setState(() {
      _events = _store.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('조회 기록')),
      body: FutureBuilder<List<LookupEvent>>(
        future: _events,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }
          final events = snapshot.data ?? const <LookupEvent>[];
          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
            children: [
              Text(
                '최근 14일 동안의 조회예요. 시각과 약 500m 격자 위치만 이 폰에 저장돼요.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: context.ridey.muted,
                ),
              ),
              const SizedBox(height: 20),
              if (events.isEmpty)
                const _EmptyHabits()
              else ...[
                for (final event in events.reversed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _HabitTile(event: event),
                  ),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: _clear, child: const Text('기록 지우기')),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _HabitTile extends StatelessWidget {
  const _HabitTile({required this.event});

  final LookupEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final where = event.latitude == null || event.longitude == null
        ? '위치 없음'
        : '${event.latitude!.toStringAsFixed(3)}, ${event.longitude!.toStringAsFixed(3)}';
    final subject = event.subject;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: context.ridey.line),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(lookupKindLabel(event.kind), style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            [
              formatLookupTime(event.at),
              if (subject != null && subject.isNotEmpty) subject,
              where,
            ].join(' · '),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: context.ridey.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHabits extends StatelessWidget {
  const _EmptyHabits();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: context.ridey.line),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '아직 조회 기록이 없어요. 번호를 확인하거나 대여소를 열면 여기에 남아요.',
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: context.ridey.muted),
      ),
    );
  }
}
