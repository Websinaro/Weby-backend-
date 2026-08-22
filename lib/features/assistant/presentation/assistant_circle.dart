import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../state/assistant_state.dart';

/// The signature Weby orb. This is the one visual element the whole
/// product hinges on - it needs to read as alive, responsive, and
/// unmistakably "Weby" whether it's a full-screen hero or a small
/// floating overlay circle.
///
/// Built entirely from CustomPainter + AnimationControllers (no image
/// assets), so it scales crisply at any size, from a 56px floating
/// bubble to a 240px hero on the home screen.
class AssistantCircle extends StatefulWidget {
  const AssistantCircle({super.key, required this.state, this.size = 140});

  final AssistantVisualState state;
  final double size;

  @override
  State<AssistantCircle> createState() => _AssistantCircleState();
}

class _AssistantCircleState extends State<AssistantCircle> with TickerProviderStateMixin {
  // Slow continuous pulse - drives the breathing rings and the idle
  // "alive" feel even when nothing is happening.
  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();

  // Faster rotation - used for the processing "thinking" ring.
  late final AnimationController _spinController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  // Drives the inner waveform bars while listening/speaking.
  late final AnimationController _waveController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  // Snappy scale-in/out whenever the state itself changes (e.g. idle ->
  // listening) so transitions feel deliberate rather than just cross-fading.
  late final AnimationController _stateChangeController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: 1,
  );

  @override
  void didUpdateWidget(covariant AssistantCircle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _stateChangeController
        ..value = 0.85
        ..animateTo(1, curve: Curves.elasticOut, duration: const Duration(milliseconds: 500));
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _spinController.dispose();
    _waveController.dispose();
    _stateChangeController.dispose();
    super.dispose();
  }

  ({List<Color> colors, double coreEnergy}) _paletteFor(AssistantVisualState s) {
    switch (s) {
      case AssistantVisualState.idle:
        return (colors: [AppColors.glowViolet, AppColors.glowCyan], coreEnergy: 0.35);
      case AssistantVisualState.listening:
        return (colors: [AppColors.glowViolet, AppColors.glowPink], coreEnergy: 0.9);
      case AssistantVisualState.processing:
        return (colors: [AppColors.glowCyan, AppColors.glowViolet], coreEnergy: 0.6);
      case AssistantVisualState.speaking:
        return (colors: [AppColors.glowCyan, AppColors.glowPink], coreEnergy: 1.0);
      case AssistantVisualState.executing:
        return (colors: [AppColors.success, AppColors.glowCyan], coreEnergy: 0.8);
      case AssistantVisualState.error:
        return (colors: [AppColors.error, AppColors.glowPink], coreEnergy: 0.7);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = _paletteFor(widget.state);

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _pulseController,
          _spinController,
          _waveController,
          _stateChangeController,
        ]),
        builder: (context, _) {
          return Transform.scale(
            scale: _stateChangeController.value,
            child: CustomPaint(
              painter: _OrbPainter(
                pulseT: _pulseController.value,
                spinT: _spinController.value,
                waveT: _waveController.value,
                colors: palette.colors,
                coreEnergy: palette.coreEnergy,
                isProcessing: widget.state == AssistantVisualState.processing,
                showWaveform: widget.state == AssistantVisualState.listening ||
                    widget.state == AssistantVisualState.speaking,
                isError: widget.state == AssistantVisualState.error,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  _OrbPainter({
    required this.pulseT,
    required this.spinT,
    required this.waveT,
    required this.colors,
    required this.coreEnergy,
    required this.isProcessing,
    required this.showWaveform,
    required this.isError,
  });

  final double pulseT; // 0..1 loop
  final double spinT; // 0..1 loop
  final double waveT; // 0..1 loop
  final List<Color> colors;
  final double coreEnergy; // 0..1, how "active" the core glow looks
  final bool isProcessing;
  final bool showWaveform;
  final bool isError;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = size.shortestSide / 2;

    _paintBreathingRings(canvas, center, maxRadius);
    if (isProcessing) _paintProcessingRing(canvas, center, maxRadius);
    _paintCore(canvas, center, maxRadius);
    if (showWaveform) _paintWaveform(canvas, center, maxRadius);
    if (isError) _paintErrorPulse(canvas, center, maxRadius);
  }

  // Three staggered expanding-and-fading rings, like ripples on water -
  // constant even at idle so the orb never looks static/dead.
  void _paintBreathingRings(Canvas canvas, Offset center, double maxRadius) {
    for (var i = 0; i < 3; i++) {
      final phase = (pulseT + i / 3) % 1.0;
      final radius = maxRadius * (0.55 + phase * 0.45);
      final opacity = (1 - phase) * 0.35 * (0.4 + coreEnergy * 0.6);

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..shader = SweepGradient(
          colors: [...colors, colors.first],
          transform: GradientRotation(spinT * 2 * pi),
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..color = Colors.white.withOpacity(opacity);

      canvas.drawCircle(center, radius, paint);
    }
  }

  // A rotating gradient arc ring - the classic "thinking" indicator,
  // drawn as a sweep gradient stroked ring rather than a plain spinner.
  void _paintProcessingRing(Canvas canvas, Offset center, double maxRadius) {
    final radius = maxRadius * 0.82;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: pi * 1.4,
        colors: [colors.first.withOpacity(0), colors.first, colors.last],
        transform: GradientRotation(spinT * 2 * pi),
      ).createShader(rect);
    canvas.drawArc(rect, spinT * 2 * pi, pi * 1.4, false, paint);
  }

  // The solid glowing core - a radial gradient sphere with a soft outer
  // blur (via multiple translucent circles) standing in for a glow shader.
  void _paintCore(Canvas canvas, Offset center, double maxRadius) {
    final coreRadius = maxRadius * (0.5 + coreEnergy * 0.08 + sin(pulseT * 2 * pi) * 0.02);

    // Soft outer glow (cheap blur substitute: layered fading circles).
    for (var i = 4; i >= 1; i--) {
      final glowRadius = coreRadius + i * maxRadius * 0.09;
      canvas.drawCircle(
        center,
        glowRadius,
        Paint()
          ..color = colors.first.withOpacity(0.05 * coreEnergy)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, maxRadius * 0.18),
      );
    }

    final corePaint = Paint()
      ..shader = RadialGradient(
        colors: [Color.lerp(colors.first, Colors.white, 0.15)!, colors.last],
        stops: const [0.15, 1],
      ).createShader(Rect.fromCircle(center: center, radius: coreRadius));

    canvas.drawCircle(center, coreRadius, corePaint);

    // A subtle inner highlight so the sphere reads as glassy, not flat.
    canvas.drawCircle(
      center.translate(-coreRadius * 0.28, -coreRadius * 0.32),
      coreRadius * 0.28,
      Paint()..color = Colors.white.withOpacity(0.18),
    );
  }

  // A small equalizer-style waveform drawn across the core while
  // listening/speaking - the clearest possible "I can hear you /
  // I'm talking" signal.
  void _paintWaveform(Canvas canvas, Offset center, double maxRadius) {
    const barCount = 5;
    final barWidth = maxRadius * 0.09;
    final gap = maxRadius * 0.11;
    final totalWidth = barCount * barWidth + (barCount - 1) * gap;
    final startX = center.dx - totalWidth / 2 + barWidth / 2;

    final paint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..strokeWidth = barWidth
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < barCount; i++) {
      // Distinct phase per bar so they don't move in lockstep.
      final phase = (waveT + i * 0.18) % 1.0;
      final amplitude = (0.35 + 0.65 * (0.5 + 0.5 * sin(phase * 2 * pi))) * maxRadius * 0.42;
      final x = startX + i * (barWidth + gap);
      canvas.drawLine(
        Offset(x, center.dy - amplitude / 2),
        Offset(x, center.dy + amplitude / 2),
        paint,
      );
    }
  }

  void _paintErrorPulse(Canvas canvas, Offset center, double maxRadius) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = AppColors.error.withOpacity(0.5 + 0.5 * sin(pulseT * 2 * pi));
    canvas.drawCircle(center, maxRadius * 0.95, paint);
  }

  @override
  bool shouldRepaint(covariant _OrbPainter oldDelegate) => true;
}
