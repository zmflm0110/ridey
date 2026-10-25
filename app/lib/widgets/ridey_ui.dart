import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ridey_app/design/ridey_theme.dart';

/// Building blocks shared with the web demo (web/style.css): the wordmark,
/// 1px-line cards with one-line rows, round icons, pills, and the brand motion.

/// 'RIDEY' in Unbounded with the signal dot sitting on the baseline.
class RideyWordmark extends StatelessWidget {
  const RideyWordmark({super.key, this.size = 24, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final dot = size * .27;
    return Semantics(
      label: 'RIDEY',
      excludeSemantics: true,
      child: Text.rich(
        TextSpan(
          children: [
            const TextSpan(text: 'RIDEY'),
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: Padding(
                padding: EdgeInsets.only(left: size * .06),
                child: Container(
                  width: dot,
                  height: dot,
                  decoration: BoxDecoration(
                    color: context.ridey.signal,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        ),
        style: TextStyle(
          fontFamily: RideyTheme.numberFamily,
          fontWeight: FontWeight.w800,
          fontSize: size,
          height: 1,
          letterSpacing: -size * .02,
          color: color ?? Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

/// Shrinks to 97% while pressed — the web `button:active` — instead of a ripple.
class RideyPressable extends StatefulWidget {
  const RideyPressable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = .97,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final String? semanticLabel;

  @override
  State<RideyPressable> createState() => _RideyPressableState();
}

class _RideyPressableState extends State<RideyPressable> {
  var _down = false;

  void _press(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Semantics(
      button: enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _press(true) : null,
        onTapUp: enabled ? (_) => _press(false) : null,
        onTapCancel: enabled ? () => _press(false) : null,
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? widget.scale : 1,
          duration: RideyMotion.of(context, RideyMotion.press),
          curve: RideyMotion.ease,
          child: widget.child,
        ),
      ),
    );
  }
}

/// The web's pill buttons: ink for the one main action, fill for the rest.
/// They shrink while pressed instead of rippling.
class RideyButton extends StatelessWidget {
  const RideyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.compact = false,
    this.busy = false,
  }) : primary = true;

  const RideyButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.compact = false,
    this.busy = false,
  }) : primary = false;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool primary;
  final bool compact;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final background = primary ? theme.colorScheme.onSurface : context.ridey.fill;
    final foreground = primary
        ? theme.scaffoldBackgroundColor
        : theme.colorScheme.onSurface;
    final enabled = onPressed != null && !busy;

    return AnimatedOpacity(
      opacity: onPressed == null ? .45 : 1,
      duration: RideyMotion.of(context, const Duration(milliseconds: 200)),
      child: RideyPressable(
        onTap: enabled ? onPressed : null,
        child: Container(
          height: compact ? 44 : (primary ? 54 : 52),
          padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 20),
          decoration: ShapeDecoration(
            color: background,
            shape: const StadiumBorder(),
          ),
          child: Row(
            mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy)
                SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: foreground,
                  ),
                )
              else if (icon != null)
                Icon(icon, size: 20, color: foreground),
              if (busy || icon != null) const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontSize: primary && !compact ? 17 : 16,
                    color: foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// White card with a 1px line, radius 24 (web `.card`).
class RideyCard extends StatelessWidget {
  const RideyCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color,
    this.gradient,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Gradient? gradient;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null
            ? color ?? Theme.of(context).colorScheme.surface
            : null,
        gradient: gradient,
        border: Border.all(color: borderColor ?? context.ridey.line),
        borderRadius: BorderRadius.circular(24),
      ),
      child: child,
    );
  }
}

/// A card of one-line rows split by hairlines (web `.card.list` + `.rows`).
class RideyListCard extends StatelessWidget {
  const RideyListCard({super.key, required this.children, this.enter = true});

  final List<Widget> children;

  /// Rows rise in one after another (web `.enter > li`).
  final bool enter;

  @override
  Widget build(BuildContext context) {
    return RideyCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(),
            enter ? RideyEnter(index: i, child: children[i]) : children[i],
          ],
        ],
      ),
    );
  }
}

/// One row: optional round icon, a bold line and a muted line, a number on
/// the right, and anything that belongs under it (bike chips).
class RideyRow extends StatelessWidget {
  const RideyRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.below,
    this.onTap,
    this.semanticLabel,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final Widget? below;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 14)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: context.ridey.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            ],
          ),
          if (below != null)
            Padding(
              padding: EdgeInsets.only(
                left: leading == null ? 0 : 56,
                top: 10,
              ),
              child: below!,
            ),
        ],
      ),
    );
    if (onTap == null) return row;
    return RideyPressable(
      onTap: onTap,
      scale: .98,
      semanticLabel: semanticLabel,
      child: row,
    );
  }
}

enum RideyTone { strong, normal, ok, neutral }

/// 42px round icon (web `.ico`): strong alert = signal ring, plain alert =
/// grey, checked = calm blue. Solid orange is kept for dots and big numbers.
class RideyIco extends StatelessWidget {
  const RideyIco({super.key, required this.icon, this.tone = RideyTone.neutral});

  final IconData icon;
  final RideyTone tone;

  @override
  Widget build(BuildContext context) {
    final c = context.ridey;
    final ink = Theme.of(context).colorScheme.onSurface;
    final (background, foreground) = switch (tone) {
      RideyTone.strong => (c.signalSoft, c.signalText),
      RideyTone.normal => (c.fill, c.muted),
      RideyTone.ok => (c.calmSoft, c.calmText),
      RideyTone.neutral => (c.fill, ink),
    };
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: tone == RideyTone.strong
            ? Border.all(color: c.signal, width: 2)
            : null,
      ),
      child: Icon(icon, size: 20, color: foreground),
    );
  }
}

/// A number in Unbounded, e.g. the row count on the right (web `.rows .n`).
class RideyNumber extends StatelessWidget {
  const RideyNumber(this.text, {super.key, this.color, this.size = 15});

  final String text;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: context
          .rideyNumbers(Theme.of(context).textTheme.titleMedium)
          ?.copyWith(
            fontSize: size,
            color: color ?? Theme.of(context).colorScheme.onSurface,
            letterSpacing: -size * .04,
          ),
    );
  }
}

/// A small pill (web `.tag`).
class RideyTag extends StatelessWidget {
  const RideyTag(this.label, {super.key, required this.background, required this.foreground});

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: foreground,
        ),
      ),
    );
  }
}

/// Section heading with a muted note on the right (web `h2 .muted`).
class RideySectionTitle extends StatelessWidget {
  const RideySectionTitle(this.title, {super.key, this.note});

  final String title;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 30, 4, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(title, style: theme.textTheme.titleLarge),
          if (note != null) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                note!,
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  color: context.ridey.muted,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Fades in while rising [offset] px; [index] staggers siblings by [step].
/// One controller with an Interval, so no timers are left behind.
class RideyEnter extends StatefulWidget {
  const RideyEnter({
    super.key,
    required this.child,
    this.index = 0,
    this.step = const Duration(milliseconds: 35),
    this.offset = 10,
  });

  final Widget child;
  final int index;
  final Duration step;
  final double offset;

  @override
  State<RideyEnter> createState() => _RideyEnterState();
}

class _RideyEnterState extends State<RideyEnter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _t;
  var _started = false;

  @override
  void initState() {
    super.initState();
    final delay = widget.step * math.min(widget.index, 12);
    final total = delay + RideyMotion.enter;
    _controller = AnimationController(vsync: this, duration: total);
    _t = CurvedAnimation(
      parent: _controller,
      curve: Interval(
        delay.inMicroseconds / total.inMicroseconds,
        1,
        curve: RideyMotion.ease,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (RideyMotion.reduced(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _t,
      child: AnimatedBuilder(
        animation: _t,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, widget.offset * (1 - _t.value)),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

/// A result card arriving on the spring (web `.result` card-in): up 14px
/// from 97% while fading in. Give it a new key to play again.
class RideyPopIn extends StatefulWidget {
  const RideyPopIn({super.key, required this.child});

  final Widget child;

  @override
  State<RideyPopIn> createState() => _RideyPopInState();
}

class _RideyPopInState extends State<RideyPopIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  var _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (RideyMotion.reduced(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final s = RideyMotion.spring.transform(t);
        return Opacity(
          opacity: RideyMotion.ease.transform(math.min(1, t * 1.6)),
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - s)),
            child: Transform.scale(scale: .97 + .03 * s, child: child),
          ),
        );
      },
      child: widget.child,
    );
  }
}

/// Counts from 0 (or the previous value) up to [value] — web '숫자 올림'.
class RideyCountUp extends StatelessWidget {
  const RideyCountUp({super.key, required this.value, required this.style});

  final int value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: RideyMotion.of(context, const Duration(milliseconds: 1100)),
      curve: RideyMotion.ease,
      builder: (context, v, _) => Text(
        '${v.round()}',
        semanticsLabel: '$value',
        style: style,
      ),
    );
  }
}

/// The live dot: a ring spreads from it a few times when fresh data lands
/// (web `.live::before` ping). Finite on purpose — it marks an arrival.
class RideyPing extends StatefulWidget {
  const RideyPing({
    super.key,
    required this.color,
    this.size = 8,
    this.pulses = 3,
  });

  final Color color;
  final double size;
  final int pulses;

  @override
  State<RideyPing> createState() => _RideyPingState();
}

class _RideyPingState extends State<RideyPing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );
  var _done = 0;
  var _started = false;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && ++_done < widget.pulses) {
        _controller.forward(from: 0);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!RideyMotion.reduced(context)) _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: CustomPaint(
        painter: _PingPainter(_controller, widget.color),
      ),
    );
  }
}

class _PingPainter extends CustomPainter {
  _PingPainter(this.t, this.color) : super(repaint: t);

  final Animation<double> t;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.width / 2;
    final p = t.value / .7;
    if (t.isAnimating && p < 1) {
      canvas.drawCircle(
        center,
        r + 9 * p,
        Paint()..color = color.withValues(alpha: .6 * (1 - p)),
      );
    }
    canvas.drawCircle(center, r, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PingPainter old) => old.color != color;
}

/// Dot texture of the hero card: dots fade out from the top-right corner,
/// like Seoul's 2,789 stations seen from far (web `.hero::before`).
class RideyDotGrid extends StatelessWidget {
  const RideyDotGrid({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(painter: _DotGridPainter(color), size: Size.infinite),
    );
  }
}

class _DotGridPainter extends CustomPainter {
  _DotGridPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const gap = 13.0;
    final cx = size.width, cy = size.height * .15;
    final rx = size.width * .75, ry = size.height * .85;
    final paint = Paint();
    for (var y = gap / 2; y < size.height; y += gap) {
      for (var x = gap / 2; x < size.width; x += gap) {
        final d = math.sqrt(math.pow((x - cx) / rx, 2) + math.pow((y - cy) / ry, 2));
        final fade = math.max(0.0, math.min(1.0, 1 - d / .72));
        if (fade <= 0) continue;
        paint.color = color.withValues(alpha: .18 * fade);
        canvas.drawCircle(Offset(x, y), 1.1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter old) => old.color != color;
}
