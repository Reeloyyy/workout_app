import 'package:flutter/material.dart';

/// Breathing cue: grows for 4 s ("Breathe in"), shrinks for 6 s
/// ("Breathe out"), looping. With reduced motion only the text is shown.
class BreathingCircle extends StatefulWidget {
  const BreathingCircle({super.key, required this.size});

  final double size;

  static const inhale = Duration(seconds: 4);
  static const exhale = Duration(seconds: 6);

  @override
  State<BreathingCircle> createState() => _BreathingCircleState();
}

class _BreathingCircleState extends State<BreathingCircle>
    with SingleTickerProviderStateMixin {
  static final _cycle = BreathingCircle.inhale + BreathingCircle.exhale;
  static final _inhaleShare =
      BreathingCircle.inhale.inMilliseconds / _cycle.inMilliseconds;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _cycle,
  )..repeat();

  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 0.55,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeInOut)),
      weight: _inhaleShare,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 0.55,
      ).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 1 - _inhaleShare,
    ),
  ]).animate(_controller);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final colors = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final inhaling = _controller.value < _inhaleShare;
        final label = Text(
          inhaling ? 'Breathe in' : 'Breathe out',
          style: Theme.of(context).textTheme.titleMedium,
        );
        if (reduceMotion) return label;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: widget.size,
              child: Center(
                child: Transform.scale(
                  scale: _scale.value,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.primaryContainer,
                    ),
                    child: SizedBox.square(dimension: widget.size),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            label,
          ],
        );
      },
    );
  }
}
