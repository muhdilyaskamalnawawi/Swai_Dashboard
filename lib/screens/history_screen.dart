import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/sensor_reading.dart';
import '../services/supabase_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _supabaseService = SupabaseService();
  List<SensorReading> _readings = [];
  bool _isLoading = true;
  int _selectedMetric = 0; // 0: pH, 1: Temp, 2: TDS

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory({int days = 7}) async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final startDate = now.subtract(Duration(days: days));

      final readings = await _supabaseService.getHistory(
        limit: 1000,
        startDate: startDate,
        endDate: now,
      );

      if (!mounted) return;
      setState(() {
        _readings = readings.reversed.toList(); // Sort ascending by time
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading history: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  List<FlSpot> _getChartData() {
    if (_readings.isEmpty) return [];

    final spots = <FlSpot>[];
    for (int i = 0; i < _readings.length; i++) {
      final reading = _readings[i];
      final value = _selectedMetric == 0
          ? reading.pH
          : _selectedMetric == 1
              ? reading.temp
              : reading.tds;
      spots.add(FlSpot(i.toDouble(), value));
    }
    return spots;
  }

  String _getMetricLabel() {
    switch (_selectedMetric) {
      case 0:
        return 'pH Level';
      case 1:
        return 'Temperature (°C)';
      case 2:
        return 'TDS (ppm)';
      default:
        return 'Unknown';
    }
  }

  double _getMinY() {
    switch (_selectedMetric) {
      case 0:
        return 0;
      case 1:
        return 0;
      case 2:
        return 0;
      default:
        return 0;
    }
  }

  double _getMaxY() {
    switch (_selectedMetric) {
      case 0:
        return 14;
      case 1:
        return 50;
      case 2:
        return 1500;
      default:
        return 100;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sensor History'),
        elevation: 2,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Metric Selection
                    Text(
                      'Select Metric',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildMetricButton('pH', 0),
                          const SizedBox(width: 8),
                          _buildMetricButton('Temperature', 1),
                          const SizedBox(width: 8),
                          _buildMetricButton('TDS', 2),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Chart
                    Text(
                      _getMetricLabel(),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                          height: 300,
                          child: _readings.isEmpty
                              ? Center(
                                  child: Text(
                                    'No data available',
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                )
                              : LineChart(
                                  LineChartData(
                                    gridData: FlGridData(
                                      show: true,
                                      drawVerticalLine: false,
                                      horizontalInterval: 2,
                                    ),
                                    titlesData: FlTitlesData(
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 30,
                                          interval: (_readings.length / 5)
                                              .ceil()
                                              .toDouble(),
                                          getTitlesWidget:
                                              (double value, TitleMeta meta) {
                                            final index = value.toInt();
                                            if (index < 0 ||
                                                index >= _readings.length) {
                                              return const Text('');
                                            }
                                            final time = _readings[index]
                                                .timestamp
                                                .toLocal();
                                            return Text(
                                              DateFormat('HH:mm').format(time),
                                              style:
                                                  const TextStyle(fontSize: 10),
                                            );
                                          },
                                        ),
                                      ),
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 40,
                                        ),
                                      ),
                                    ),
                                    borderData: FlBorderData(
                                      show: true,
                                      border: const Border(
                                        left: BorderSide(),
                                        bottom: BorderSide(),
                                      ),
                                    ),
                                    minY: _getMinY(),
                                    maxY: _getMaxY(),
                                    lineBarsData: [
                                      LineChartBarData(
                                        spots: _getChartData(),
                                        isCurved: true,
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.blue.shade400,
                                            Colors.blue.shade800,
                                          ],
                                        ),
                                        barWidth: 2,
                                        isStrokeCapRound: true,
                                        dotData: FlDotData(
                                          show: false,
                                        ),
                                        belowBarData: BarAreaData(
                                          show: true,
                                          gradient: LinearGradient(
                                            colors: [
                                              Colors.blue.shade200
                                                  .withValues(alpha: 0.3),
                                              Colors.blue.shade100
                                                  .withValues(alpha: 0.1),
                                            ],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Statistics
                    if (_readings.isNotEmpty) ...[
                      Text(
                        'Statistics',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      _buildStatisticsCards(),
                    ],
                    const SizedBox(height: 24),

                    // Time Range Selector
                    Text(
                      'Time Range',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildTimeRangeButton('7 Days', 7),
                          const SizedBox(width: 8),
                          _buildTimeRangeButton('14 Days', 14),
                          const SizedBox(width: 8),
                          _buildTimeRangeButton('30 Days', 30),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildMetricButton(String label, int index) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor:
            _selectedMetric == index ? Colors.blue : Colors.grey.shade300,
        foregroundColor: _selectedMetric == index ? Colors.white : Colors.black,
      ),
      onPressed: () => setState(() => _selectedMetric = index),
      child: Text(label),
    );
  }

  Widget _buildTimeRangeButton(String label, int days) {
    return OutlinedButton(
      onPressed: () => _loadHistory(days: days),
      child: Text(label),
    );
  }

  Widget _buildStatisticsCards() {
    final data = _getChartData();
    if (data.isEmpty) return const SizedBox();

    final values = data.map((spot) => spot.y).toList();
    final avg = values.reduce((a, b) => a + b) / values.length;
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);

    return Row(
      children: [
        Expanded(
          child: _buildStatCard('Average', avg.toStringAsFixed(2)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard('Min', min.toStringAsFixed(2)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatCard('Max', max.toStringAsFixed(2)),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
