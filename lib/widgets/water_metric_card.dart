import 'package:flutter/material.dart';

enum MetricStatus { good, caution, alert }

class WaterMetricCard extends StatelessWidget {
  final String label;
  final double value;
  final String unit;
  final MetricStatus status;
  final IconData icon;
  final Duration delay;
  final bool isStatusCard; // New parameter for status display

  const WaterMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.status,
    required this.icon,
    this.delay = Duration.zero,
    this.isStatusCard = false, // Default to false
  });

  @override
  Widget build(BuildContext context) {
    final config = _getStatusConfig();

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 500),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
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
              Colors.white.withValues(alpha: 0.75),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.6),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: config.shadowColor.withValues(alpha: 0.25),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.8),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Background decoration
              Positioned(
                bottom: -16,
                right: -16,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.transparent,
                        const Color(0xFFF1F5F9).withValues(alpha: 0.5),
                      ],
                    ),
                  ),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon and status indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: config.bgColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            icon,
                            size: 20,
                            color: config.iconColor,
                          ),
                        ),
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: config.indicatorColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: config.indicatorColor
                                    .withValues(alpha: 0.5),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.5),
                              width: 2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Label
                    Text(
                      label.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B), // slate-500
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Value or Status Text
                    isStatusCard
                        ? Text(
                            unit, // Display status text
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B), // slate-800
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                value.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B), // slate-800
                                  height: 1,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                unit,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF94A3B8), // slate-400
                                ),
                              ),
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

  _StatusConfig _getStatusConfig() {
    switch (status) {
      case MetricStatus.good:
        return _StatusConfig(
          iconColor: const Color(0xFF059669), // emerald-600
          bgColor: const Color(0xFFD1FAE5), // emerald-100
          indicatorColor: const Color(0xFF10B981), // emerald-500
          shadowColor: const Color(0xFFD1FAE5), // emerald-100
        );
      case MetricStatus.caution:
        return _StatusConfig(
          iconColor: const Color(0xFFD97706), // amber-600
          bgColor: const Color(0xFFFEF3C7), // amber-100
          indicatorColor: const Color(0xFFF59E0B), // amber-500
          shadowColor: const Color(0xFFFEF3C7), // amber-100
        );
      case MetricStatus.alert:
        return _StatusConfig(
          iconColor: const Color(0xFFDC2626), // rose-600
          bgColor: const Color(0xFFFEE2E2), // rose-100
          indicatorColor: const Color(0xFFEF4444), // rose-500
          shadowColor: const Color(0xFFFEE2E2), // rose-100
        );
    }
  }
}

class _StatusConfig {
  final Color iconColor;
  final Color bgColor;
  final Color indicatorColor;
  final Color shadowColor;

  _StatusConfig({
    required this.iconColor,
    required this.bgColor,
    required this.indicatorColor,
    required this.shadowColor,
  });
}
