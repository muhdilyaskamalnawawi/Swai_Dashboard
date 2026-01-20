import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../models/sensor_reading.dart';
import '../services/supabase_service.dart';
import '../widgets/wave_background.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _supabaseService = SupabaseService();
  List<SensorReading> _readings = [];
  bool _isLoading = true;
  bool _isDayReadingsLoading = true;
  int _selectedMetric = 0; // 0: pH, 1: Temp, 2: TDS
  int? _selectedDays; // null means show all recent data

  DateTime _selectedListDate = DateTime.now();
  List<SensorReading> _dayReadings = [];
  bool _dayExpanded = false;
  static const int _dayCollapsedLimit = 10;

  StreamSubscription<SensorReading?>? _latestSubscription;
  Timer? _autoRefreshTimer;
  bool _autoRefreshInFlight = false;
  bool _dayReadingsInFlight = false;

  @override
  void initState() {
    super.initState();
    _loadRecentHistory();
    unawaited(_refreshDayReadings());

    // Auto-refresh when new readings arrive.
    _latestSubscription = _supabaseService.getLatestReadingStream().listen(
      (reading) {
        if (!mounted || reading == null) return;
        _upsertReading(reading);
        _upsertDayReadingIfMatches(reading);
      },
      onError: (e) {
        debugPrint('❌ History realtime error: $e');
      },
    );

    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      unawaited(_pollHistory());
    });
  }

  Future<void> _pollHistory() async {
    if (!mounted) return;
    if (_autoRefreshInFlight) return;

    _autoRefreshInFlight = true;
    try {
      final now = DateTime.now();
      final readings = await _supabaseService.getHistory(
        limit: _selectedDays == null ? 100 : 1000,
        startDate: _selectedDays == null
            ? null
            : now.subtract(Duration(days: _selectedDays!)),
        endDate: _selectedDays == null ? null : now,
      );

      if (!mounted) return;
      final next = readings.reversed.toList();

      final shouldUpdate = next.length != _readings.length ||
          (next.isNotEmpty &&
              (_readings.isEmpty ||
                  next.last.id != _readings.last.id ||
                  next.last.timestamp != _readings.last.timestamp));

      if (!shouldUpdate) return;

      debugPrint('🔁 History poll refresh: updating chart data');
      setState(() {
        _readings = next;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ History poll refresh error: $e');
    } finally {
      _autoRefreshInFlight = false;
    }

    // Refresh day list only when viewing today's date.
    final nowLocal = DateTime.now();
    final selectedLocal = DateTime(
      _selectedListDate.year,
      _selectedListDate.month,
      _selectedListDate.day,
    );
    final todayLocal = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
    if (selectedLocal == todayLocal) {
      unawaited(_refreshDayReadings());
    }
  }

  @override
  void dispose() {
    _latestSubscription?.cancel();
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  void _upsertReading(SensorReading reading) {
    // Respect selected time range (if any).
    if (_selectedDays != null) {
      final now = DateTime.now();
      final startDate = now.subtract(Duration(days: _selectedDays!));
      if (reading.timestamp.isBefore(startDate) ||
          reading.timestamp.isAfter(now)) {
        return;
      }
    }

    final idx = _readings.indexWhere((r) => r.id == reading.id);
    if (idx >= 0) {
      _readings[idx] = reading;
    } else {
      _readings.add(reading);
    }

    _readings.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    if (_readings.length > 1000) {
      _readings = _readings.sublist(_readings.length - 1000);
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  DateTime _startOfDayLocal(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  DateTime _endOfDayLocal(DateTime date) =>
      DateTime(date.year, date.month, date.day, 23, 59, 59, 999);

  Future<void> _refreshDayReadings() async {
    if (!mounted) return;
    if (_dayReadingsInFlight) return;

    _dayReadingsInFlight = true;
    try {
      final startLocal = _startOfDayLocal(_selectedListDate);
      final endLocal = _endOfDayLocal(_selectedListDate);

      final startUtc = startLocal.toUtc();
      final endUtc = endLocal.toUtc();

      final day = await _supabaseService.getHistory(
        limit: 1000,
        startDate: startUtc,
        endDate: endUtc,
      );

      if (!mounted) return;

      final shouldUpdate = day.length != _dayReadings.length ||
          (day.isNotEmpty &&
              (_dayReadings.isEmpty ||
                  day.first.id != _dayReadings.first.id ||
                  day.first.timestamp != _dayReadings.first.timestamp));

      if (!shouldUpdate) {
        if (_isDayReadingsLoading) {
          setState(() => _isDayReadingsLoading = false);
        }
        return;
      }

      setState(() {
        _dayReadings = day; // DB query already ordered newest first
        _isDayReadingsLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Day readings refresh error: $e');
      if (mounted && _isDayReadingsLoading) {
        setState(() => _isDayReadingsLoading = false);
      }
    } finally {
      _dayReadingsInFlight = false;
    }
  }

  void _upsertDayReadingIfMatches(SensorReading reading) {
    final readingLocal = reading.timestamp.toLocal();
    final selectedLocal = _startOfDayLocal(_selectedListDate);
    if (readingLocal.year != selectedLocal.year ||
        readingLocal.month != selectedLocal.month ||
        readingLocal.day != selectedLocal.day) {
      return;
    }

    final idx = _dayReadings.indexWhere((r) => r.id == reading.id);
    if (idx >= 0) {
      _dayReadings[idx] = reading;
    } else {
      _dayReadings.add(reading);
    }

    _dayReadings.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    if (_dayReadings.length > 1000) {
      _dayReadings = _dayReadings.sublist(0, 1000);
    }

    if (mounted) {
      setState(() {
        _isDayReadingsLoading = false;
      });
    }
  }

  // Load recent data without date filtering
  Future<void> _loadRecentHistory() async {
    setState(() {
      _isLoading = true;
      _selectedDays = null;
    });
    try {
      debugPrint('📊 Loading recent history from Supabase...');

      final readings = await _supabaseService.getHistory(
        limit: 100, // Get last 100 readings
      );

      debugPrint('📊 Loaded ${readings.length} recent readings');

      if (!mounted) return;
      setState(() {
        _readings = readings.reversed.toList(); // Sort ascending by time
        _isLoading = false;
      });

      if (readings.isEmpty) {
        debugPrint(
            '⚠️ No data in Supabase - Graph will start once Arduino sends readings');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'No data yet. Graph will show data once your Arduino starts sending readings.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error loading recent history: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading history: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  // Load history for specific date range (for old history)
  Future<void> _loadHistory({int days = 7}) async {
    setState(() {
      _isLoading = true;
      _selectedDays = days;
    });
    try {
      final now = DateTime.now();
      final startDate = now.subtract(Duration(days: days));

      debugPrint('📊 Loading history: $days days, from $startDate to $now');

      final readings = await _supabaseService.getHistory(
        limit: 1000,
        startDate: startDate,
        endDate: now,
      );

      debugPrint('📊 Loaded ${readings.length} readings from database');

      if (!mounted) return;
      setState(() {
        _readings = readings.reversed.toList(); // Sort ascending by time
        _isLoading = false;
      });

      if (readings.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No data found for selected period.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error loading history: $e');
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

  Future<void> _pickListDate() async {
    final initial = DateTime(
      _selectedListDate.year,
      _selectedListDate.month,
      _selectedListDate.day,
    );
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (!mounted || picked == null) return;

    setState(() {
      _selectedListDate = picked;
      _dayExpanded = false;
      _isDayReadingsLoading = true;
    });
    unawaited(_refreshDayReadings());
  }

  List<SensorReading> _getVisibleDayReadings() {
    if (_dayExpanded) return _dayReadings;
    return _dayReadings.take(_dayCollapsedLimit).toList(growable: false);
  }

  Widget _buildDayReadingsList() {
    if (_isDayReadingsLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 14),
        child: Center(
          child: SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(
              strokeWidth: 3,
            ),
          ),
        ),
      );
    }

    if (_dayReadings.isEmpty) {
      return const Center(
        child: Text(
          'No readings yet',
          style: TextStyle(
            color: Color(0xFF94A3B8), // slate-400
          ),
        ),
      );
    }

    final visible = _getVisibleDayReadings();

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: visible.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color: const Color(0xFFE2E8F0).withValues(alpha: 0.6),
      ),
      itemBuilder: (context, index) {
        final reading = visible[index];
        final ts = DateFormat('yyyy-MM-dd HH:mm:ss')
            .format(reading.timestamp.toLocal());

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showReadingDetailsPopup(reading),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      ts,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF1E293B), // slate-800
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.open_in_new,
                    size: 16,
                    color: Color(0xFF94A3B8), // slate-400
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showReadingDetailsPopup(SensorReading reading) {
    final ts = DateFormat('yyyy-MM-dd HH:mm:ss').format(reading.timestamp);
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reading Details'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Timestamp', ts),
                const SizedBox(height: 8),
                _buildDetailRow('pH', reading.pH.toStringAsFixed(2)),
                _buildDetailRow(
                    'Temperature', '${reading.temp.toStringAsFixed(1)} °C'),
                _buildDetailRow('TDS', '${reading.tds.toStringAsFixed(0)} ppm'),
                const SizedBox(height: 8),
                _buildDetailRow('Prediction', reading.prediction ?? '—'),
                _buildDetailRow(
                    'Alert', reading.isAlert ? 'Yes (Critical)' : 'No'),
                const SizedBox(height: 8),
                const Text(
                  'Recommendation',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  (reading.recommendation ?? '—').trim().isEmpty
                      ? '—'
                      : (reading.recommendation ?? '—'),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF1E293B),
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? Stack(
              children: [
                const WaveBackground(),
                Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      const Color(0xFF0EA5E9), // sky-500
                    ),
                  ),
                ),
              ],
            )
          : Stack(
              children: [
                const WaveBackground(),
                SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Metric Selector
                        const Text(
                          'SELECT METRIC',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B), // slate-500
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: [
                            _buildMetricButton('pH Level', 0),
                            _buildMetricButton('Temperature', 1),
                            _buildMetricButton('TDS', 2),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Chart Card
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withValues(alpha: 0.95),
                                const Color(0xFFF0F9FF)
                                    .withValues(alpha: 0.9), // sky-50
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: const Color(0xFF0EA5E9)
                                  .withValues(alpha: 0.3),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFE2E8F0)
                                    .withValues(alpha: 0.2),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _getMetricLabel().toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B), // slate-500
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 250,
                                child: _readings.isEmpty
                                    ? const Center(
                                        child: Text(
                                          'No data available',
                                          style: TextStyle(
                                            color:
                                                Color(0xFF94A3B8), // slate-400
                                          ),
                                        ),
                                      )
                                    : LineChart(
                                        LineChartData(
                                          gridData: FlGridData(
                                            show: true,
                                            drawVerticalLine: false,
                                            horizontalInterval: 2,
                                            getDrawingHorizontalLine: (value) {
                                              return FlLine(
                                                color: const Color(0xFFE2E8F0)
                                                    .withValues(alpha: 0.5),
                                                strokeWidth: 1,
                                              );
                                            },
                                          ),
                                          titlesData: FlTitlesData(
                                            bottomTitles: AxisTitles(
                                              sideTitles: SideTitles(
                                                showTitles: true,
                                                reservedSize: 30,
                                                interval: (_readings.length / 5)
                                                    .ceil()
                                                    .toDouble(),
                                                getTitlesWidget: (double value,
                                                    TitleMeta meta) {
                                                  final index = value.toInt();
                                                  if (index < 0 ||
                                                      index >=
                                                          _readings.length) {
                                                    return const Text('');
                                                  }
                                                  final time = _readings[index]
                                                      .timestamp
                                                      .toLocal();
                                                  return Text(
                                                    DateFormat('HH:mm')
                                                        .format(time),
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      color: Color(
                                                          0xFF94A3B8), // slate-400
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                            leftTitles: AxisTitles(
                                              sideTitles: SideTitles(
                                                showTitles: true,
                                                reservedSize: 40,
                                                getTitlesWidget: (value, meta) {
                                                  return Text(
                                                    value.toStringAsFixed(1),
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      color: Color(
                                                          0xFF94A3B8), // slate-400
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                            rightTitles: const AxisTitles(
                                              sideTitles:
                                                  SideTitles(showTitles: false),
                                            ),
                                            topTitles: const AxisTitles(
                                              sideTitles:
                                                  SideTitles(showTitles: false),
                                            ),
                                          ),
                                          borderData: FlBorderData(
                                            show: true,
                                            border: const Border(
                                              left: BorderSide(
                                                color: Color(0xFFE2E8F0),
                                              ),
                                              bottom: BorderSide(
                                                color: Color(0xFFE2E8F0),
                                              ),
                                            ),
                                          ),
                                          minY: _getMinY(),
                                          maxY: _getMaxY(),
                                          lineBarsData: [
                                            LineChartBarData(
                                              spots: _getChartData(),
                                              isCurved: true,
                                              gradient: const LinearGradient(
                                                colors: [
                                                  Color(0xFF0EA5E9), // sky-500
                                                  Color(0xFF0284C7), // sky-600
                                                ],
                                              ),
                                              barWidth: 3,
                                              isStrokeCapRound: true,
                                              dotData:
                                                  const FlDotData(show: false),
                                              belowBarData: BarAreaData(
                                                show: true,
                                                gradient: LinearGradient(
                                                  colors: [
                                                    const Color(0xFF0EA5E9)
                                                        .withValues(alpha: 0.3),
                                                    const Color(0xFF0EA5E9)
                                                        .withValues(
                                                            alpha: 0.05),
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
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Statistics
                        if (_readings.isNotEmpty) ...[
                          const Text(
                            'STATISTICS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B), // slate-500
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildStatisticsCards(),
                          const SizedBox(height: 24),
                        ],

                        // Time Range Selector
                        const Text(
                          'TIME RANGE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B), // slate-500
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: [
                            _buildRecentButton('Recent'),
                            _buildTimeRangeButton('7 Days', 7),
                            _buildTimeRangeButton('14 Days', 14),
                            _buildTimeRangeButton('30 Days', 30),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Recent Readings List (Last 100)
                        const Text(
                          'DAY READINGS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B), // slate-500
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFE2E8F0)
                                  .withValues(alpha: 0.8),
                            ),
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      DateFormat('yyyy-MM-dd')
                                          .format(_selectedListDate),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1E293B),
                                      ),
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: _pickListDate,
                                    icon: const Icon(Icons.calendar_today,
                                        size: 16),
                                    label: const Text('Choose date'),
                                  ),
                                ],
                              ),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Showing ${_dayExpanded ? _dayReadings.length : (_dayReadings.length < _dayCollapsedLimit ? _dayReadings.length : _dayCollapsedLimit)} of ${_dayReadings.length}. Tap a time to view details.',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildDayReadingsList(),
                              if (_dayReadings.length > _dayCollapsedLimit)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _dayExpanded = !_dayExpanded;
                                      });
                                    },
                                    child: Text(
                                      _dayExpanded ? 'Show less' : 'Show more',
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildMetricButton(String label, int index) {
    final isSelected = _selectedMetric == index;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _selectedMetric = index);
      },
      backgroundColor: Colors.white.withValues(alpha: 0.8),
      selectedColor: const Color(0xFF0EA5E9), // sky-500
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : const Color(0xFF64748B),
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        fontSize: 13,
      ),
      elevation: isSelected ? 4 : 1,
      shadowColor: const Color(0xFF0EA5E9).withValues(alpha: 0.3),
      side: BorderSide(
        color: isSelected ? const Color(0xFF0EA5E9) : const Color(0xFFCBD5E1),
        width: isSelected ? 2 : 1,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  Widget _buildTimeRangeButton(String label, int days) {
    final isSelected = _selectedDays == days;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) _loadHistory(days: days);
      },
      backgroundColor: Colors.white.withValues(alpha: 0.7),
      selectedColor: const Color(0xFF0EA5E9), // sky-500
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : const Color(0xFF64748B),
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? const Color(0xFF0EA5E9) : const Color(0xFFE2E8F0),
      ),
    );
  }

  Widget _buildRecentButton(String label) {
    final isSelected = _selectedDays == null;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) _loadRecentHistory();
      },
      backgroundColor: Colors.white.withValues(alpha: 0.7),
      selectedColor: const Color(0xFF0EA5E9), // sky-500
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : const Color(0xFF64748B),
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? const Color(0xFF0EA5E9) : const Color(0xFFE2E8F0),
      ),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B), // slate-500
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B), // slate-800
            ),
          ),
        ],
      ),
    );
  }
}
