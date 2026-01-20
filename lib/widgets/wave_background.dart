import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Animated wave background with gradient ocean theme
class WaveBackground extends StatefulWidget {
  const WaveBackground({super.key});

  @override
  State<WaveBackground> createState() => _WaveBackgroundState();
}

class _WaveBackgroundState extends State<WaveBackground>
    with TickerProviderStateMixin {
  late AnimationController _controller1;
  late AnimationController _controller2;
  late AnimationController _controller3;

  @override
  void initState() {
    super.initState();
    _controller1 = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();
    _controller2 = AnimationController(
      duration: const Duration(seconds: 12),
      vsync: this,
    )..repeat();
    _controller3 = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller1.dispose();
    _controller2.dispose();
    _controller3.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Gradient background
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFECFEFF), // cyan-50
                Color(0xFFE0F2FE), // sky-100
                Color(0xFFBAE6FD), // blue-200
              ],
            ),
          ),
        ),
        // Wave 1 (Back)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: AnimatedBuilder(
            animation: _controller1,
            builder: (context, child) {
              return Transform.translate(
                offset:
                    Offset(0, -15 * math.sin(_controller1.value * 2 * math.pi)),
                child: Opacity(
                  opacity: 0.4,
                  child: CustomPaint(
                    size: Size(MediaQuery.of(context).size.width, 200),
                    painter: WavePainter(
                      color: const Color(0xFFBFDBFE), // blue-200
                      animationValue: _controller1.value,
                      waveHeight: 20,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // Wave 2 (Middle)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: AnimatedBuilder(
            animation: _controller2,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(
                  10 * math.sin(_controller2.value * 2 * math.pi),
                  -25 * math.sin(_controller2.value * 2 * math.pi),
                ),
                child: Opacity(
                  opacity: 0.3,
                  child: CustomPaint(
                    size: Size(MediaQuery.of(context).size.width, 200),
                    painter: WavePainter(
                      color: const Color(0xFF93C5FD), // blue-300
                      animationValue: _controller2.value,
                      waveHeight: 25,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // Wave 3 (Front)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: AnimatedBuilder(
            animation: _controller3,
            builder: (context, child) {
              return Transform.translate(
                offset:
                    Offset(0, -10 * math.sin(_controller3.value * 2 * math.pi)),
                child: Opacity(
                  opacity: 0.5,
                  child: CustomPaint(
                    size: Size(MediaQuery.of(context).size.width, 150),
                    painter: WavePainter(
                      color: const Color(0xFFE0F2FE), // sky-200
                      animationValue: _controller3.value,
                      waveHeight: 15,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class WavePainter extends CustomPainter {
  final Color color;
  final double animationValue;
  final double waveHeight;

  WavePainter({
    required this.color,
    required this.animationValue,
    this.waveHeight = 20,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final waveLength = size.width / 2;
    final offset = animationValue * waveLength;

    path.moveTo(0, size.height);

    for (double x = 0; x <= size.width; x++) {
      final y = size.height -
          50 -
          waveHeight * math.sin((x - offset) / waveLength * 2 * math.pi);
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(WavePainter oldDelegate) =>
      oldDelegate.animationValue != animationValue;
}
