import 'package:flutter/material.dart';
import 'package:ridey_app/design/ridey_theme.dart';

enum RideySignalState { avoid, noSignal, uncertain, completed }

class RideySignalBadge extends StatelessWidget {
  const RideySignalBadge({super.key, required this.state, this.compact = false});

  final RideySignalState state;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (label, icon, color, background) = switch (state) {
      RideySignalState.avoid => (
        '피하기',
        Icons.warning_amber_rounded,
        context.ridey.signalText,
        context.ridey.signalSoft,
      ),
      RideySignalState.noSignal => (
        '경보 없음',
        Icons.remove_circle_outline_rounded,
        context.ridey.calm,
        context.ridey.calmSoft,
      ),
      RideySignalState.uncertain => (
        '판단 어려움',
        Icons.cloud_off_outlined,
        context.ridey.signalText,
        context.ridey.signalSoft,
      ),
      RideySignalState.completed => (
        '현장 확인 완료',
        Icons.check_circle_outline_rounded,
        context.ridey.calm,
        context.ridey.calmSoft,
      ),
    };
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 14 : 16, color: color),
          SizedBox(width: compact ? 4 : 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class RideyDataConfidence extends StatelessWidget {
  const RideyDataConfidence({
    super.key,
    required this.updatedAt,
    required this.isHealthy,
    this.ratio,
    this.compact = false,
  });

  final DateTime updatedAt;
  final bool isHealthy;
  final double? ratio;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final minutes = DateTime.now()
        .difference(updatedAt)
        .inMinutes
        .clamp(0, 999);
    final fresh = minutes == 0 ? '방금 갱신' : '$minutes분 전 갱신';
    final state = isHealthy ? RideySignalState.noSignal : RideySignalState.uncertain;
    final message = isHealthy
        ? '대여 기록 $fresh'
        : ratio == null
        ? '자료 지연 · $fresh'
        : '자료 지연 ${((ratio ?? 0) * 100).round()}% · $fresh';
    return Semantics(
      label: isHealthy ? '실시간 자료, $fresh' : '자료 지연, $fresh',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isHealthy
                ? Icons.fiber_manual_record_rounded
                : Icons.error_outline_rounded,
            size: compact ? 12 : 16,
            color: isHealthy ? context.ridey.calm : context.ridey.signalText,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              message,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: state == RideySignalState.noSignal
                    ? context.ridey.calm
                    : context.ridey.signalText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RideyPageHeading extends StatelessWidget {
  const RideyPageHeading({
    super.key,
    required this.title,
    required this.description,
    this.hero = false,
  });

  final String title;
  final String description;
  final bool hero;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: hero ? context.rideyHeroText : context.rideyPageTitle,
        ),
        const SizedBox(height: 8),
        Text(
          description,
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: context.ridey.muted),
        ),
      ],
    );
  }
}
