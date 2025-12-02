import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

class GaugeWidget extends StatelessWidget {
  final String title;
  final double value;
  final double min;
  final double max;
  final double low;
  final double high;

  const GaugeWidget({super.key, required this.title, required this.value, required this.min, required this.max, required this.low, required this.high});

  @override
  Widget build(BuildContext context) {
    return SfRadialGauge(
      title: GaugeTitle(text: title),
      axes: <RadialAxis>[
        RadialAxis(minimum: min, maximum: max,
          ranges: [
            GaugeRange(startValue: min, endValue: low, color: Colors.red),
            GaugeRange(startValue: low, endValue: high, color: Colors.green),
            GaugeRange(startValue: high, endValue: max, color: Colors.red),
          ],
          pointers: [NeedlePointer(value: value)],
        )
      ],
    );
  }
}
