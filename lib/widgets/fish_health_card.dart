import 'package:flutter/material.dart';
import 'dart:math' as math;

class FishHealthCard extends StatefulWidget {
  final String status;
  final String description;
  final DateTime lastChecked;

  const FishHealthCard({
    super.key,
    required this.status,
    required this.description,
    required this.lastChecked,
  });

  @override
  State<FishHealthCard> createState() => _FishHealthCardState();
}

class _FishHealthCardState extends State<FishHealthCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final healthConfig = _getHealthConfig();

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 500),
      tween: Tween(begin: 0.95, end: 1.0),
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: math.min(scale, 1.0),
            child: child,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.95),
              const Color(0xFFF0F9FF).withValues(alpha: 0.85), // sky-50
              Colors.white.withValues(alpha: 0.7),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.5),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: healthConfig.shadowColor.withValues(alpha: 0.25),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // Decorative wave at bottom
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Opacity(
                  opacity: 0.3,
                  child: CustomPaint(
                    size: const Size(double.infinity, 80),
                    painter: DecorativeWavePainter(
                      color: const Color(0xFFBAE6FD), // blue-200
                    ),
                  ),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    // Fish icon with pulsing heart
                    Stack(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: healthConfig.bgColor,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.set_meal,
                            size: 32,
                            color: healthConfig.iconColor,
                          ),
                        ),
                        Positioned(
                          top: -4,
                          right: -4,
                          child: AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: 1.0 + 0.1 * _pulseController.value,
                                child: child,
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: healthConfig.indicatorColor
                                        .withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.favorite,
                                size: 16,
                                color: healthConfig.indicatorColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 20),
                    // Text content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Recommended Action',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B), // slate-500
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Status badge (only show if status is not empty)
                          if (widget.status.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: healthConfig.badgeColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                widget.status,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: healthConfig.badgeTextColor,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          // Description: split into Reason / Action if available
                          ..._buildReasonAction(widget.description),
                          const SizedBox(height: 8),
                        ],
                      ),
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

  List<Widget> _buildReasonAction(String description) {
    final parts = description.split('|');
    String reason = description;
    String action = '';

    if (parts.length >= 2) {
      reason = parts[0].trim();
      action = parts[1].trim();
    }

    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 16, color: Color(0xFF64748B)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              reason,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 6),
      if (action.isNotEmpty)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.set_meal, size: 16, color: Color(0xFF64748B)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                action,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
    ];
  }

  _HealthConfig _getHealthConfig() {
    final statusLower = widget.status.toLowerCase();
    if (statusLower.contains('excellent') || statusLower.contains('thriving')) {
      return _HealthConfig(
        iconColor: const Color(0xFF059669), // emerald-600
        bgColor: const Color(0xFFD1FAE5), // emerald-100
        badgeColor: const Color(0xFFD1FAE5), // emerald-100
        badgeTextColor: const Color(0xFF059669), // emerald-600
        indicatorColor: const Color(0xFF10B981), // emerald-500
        shadowColor: const Color(0xFFD1FAE5), // emerald-100
      );
    } else if (statusLower.contains('caution') ||
        statusLower.contains('monitor')) {
      return _HealthConfig(
        iconColor: const Color(0xFFD97706), // amber-600
        bgColor: const Color(0xFFFEF3C7), // amber-100
        badgeColor: const Color(0xFFFEF3C7), // amber-100
        badgeTextColor: const Color(0xFFD97706), // amber-600
        indicatorColor: const Color(0xFFF59E0B), // amber-500
        shadowColor: const Color(0xFFFEF3C7), // amber-100
      );
    } else {
      return _HealthConfig(
        iconColor: const Color(0xFFDC2626), // rose-600
        bgColor: const Color(0xFFFEE2E2), // rose-100
        badgeColor: const Color(0xFFFEE2E2), // rose-100
        badgeTextColor: const Color(0xFFDC2626), // rose-600
        indicatorColor: const Color(0xFFEF4444), // rose-500
        shadowColor: const Color(0xFFFEE2E2), // rose-100
      );
    }
  }
}

class _HealthConfig {
  final Color iconColor;
  final Color bgColor;
  final Color badgeColor;
  final Color badgeTextColor;
  final Color indicatorColor;
  final Color shadowColor;

  _HealthConfig({
    required this.iconColor,
    required this.bgColor,
    required this.badgeColor,
    required this.badgeTextColor,
    required this.indicatorColor,
    required this.shadowColor,
  });
}

class DecorativeWavePainter extends CustomPainter {
  final Color color;

  DecorativeWavePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height * 0.5);

    for (double x = 0; x <= size.width; x += 10) {
      final y = size.height * 0.5 +
          math.sin((x / size.width) * 4 * math.pi) * size.height * 0.3;
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
