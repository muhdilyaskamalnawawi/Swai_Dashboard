import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../services/supabase_service.dart';
import '../widgets/wave_background.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _recommendationEnabled = true;
  bool _notificationEnabled = true;
  bool _isLoading = true;
  bool _isDeleting = false;

  SupabaseService get _supabaseService => SupabaseService();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final recommendationEnabled =
          await SettingsService.getRecommendationEnabled();
      final notificationEnabled =
          await SettingsService.getNotificationEnabled();

      if (!mounted) return;
      setState(() {
        _recommendationEnabled = recommendationEnabled;
        _notificationEnabled = notificationEnabled;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading settings: $e')),
      );
    }
  }

  Future<void> _updateRecommendationEnabled(bool value) async {
    await SettingsService.setRecommendationEnabled(value);
    setState(() => _recommendationEnabled = value);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value
              ? 'AI Recommendations enabled'
              : 'AI Recommendations disabled (saves API quota)',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _updateNotificationEnabled(bool value) async {
    await SettingsService.setNotificationEnabled(value);
    setState(() => _notificationEnabled = value);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value ? 'Notifications enabled' : 'Notifications disabled',
        ),
        duration: const Duration(seconds: 2),
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
                    color: const Color(0xFF0EA5E9),
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
                        // AI Recommendations Section
                        _buildSectionTitle('AI RECOMMENDATIONS'),
                        const SizedBox(height: 12),
                        _buildGlassCard(
                          child: Column(
                            children: [
                              _buildSwitchTile(
                                icon: Icons.auto_awesome,
                                title: 'Enable Recommendations',
                                subtitle:
                                    'AI-powered treatment suggestions & insights',
                                value: _recommendationEnabled,
                                onChanged: _updateRecommendationEnabled,
                              ),
                              if (!_recommendationEnabled)
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFEF3C7)
                                          .withValues(alpha: 0.5), // amber-100
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: const Color(0xFFD97706)
                                            .withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.info_outline,
                                          size: 20,
                                          color: const Color(0xFFD97706),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            'Recommendations are disabled to save API quota. Enable for personalized guidance.',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFFD97706),
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

                        // Data Management Section
                        _buildSectionTitle('DATA MANAGEMENT'),
                        const SizedBox(height: 12),
                        _buildGlassCard(
                          child: Column(
                            children: [
                              _buildActionTile(
                                icon: Icons.delete_forever,
                                title: 'Reset database (delete all data)',
                                subtitle:
                                    'Use when moving sensor to a new pond',
                                onTap: _isDeleting ? () {} : _confirmDeleteAll,
                              ),
                              const Divider(height: 1),
                              _buildActionTile(
                                icon: Icons.date_range,
                                title: 'Delete data by date range',
                                subtitle:
                                    'Remove old pond data without losing everything',
                                onTap: _isDeleting ? () {} : _deleteByDateRange,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Notifications Section
                        _buildSectionTitle('ALERTS & NOTIFICATIONS'),
                        const SizedBox(height: 12),
                        _buildGlassCard(
                          child: _buildSwitchTile(
                            icon: Icons.notifications_active,
                            title: 'Enable Notifications',
                            subtitle:
                                'Get alerted when water quality is critical',
                            value: _notificationEnabled,
                            onChanged: _updateNotificationEnabled,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // About / Footer
                        Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.water_drop,
                                size: 32,
                                color: const Color(0xFF0EA5E9)
                                    .withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Smart WaterGuard Ai',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Smart Water Quality Monitoring & Ai Insights',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_isDeleting)
                  Container(
                    color: Colors.black.withValues(alpha: 0.25),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: const Color(0xFF0EA5E9),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Future<void> _confirmDeleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete ALL sensor data?'),
          content: const Text(
            'This will permanently delete all rows in Supabase table "sensor_readings".\n\n'
            'Recommended: prefer deleting a date range (old pond) instead of full reset.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete All'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    await _deleteAllData();
  }

  Future<void> _deleteAllData() async {
    setState(() => _isDeleting = true);
    try {
      final deleted = await _supabaseService.deleteAllReadings();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted $deleted rows from database.'),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  Future<void> _deleteByDateRange() async {
    final now = DateTime.now();
    final initialRange = DateTimeRange(
      start: now.subtract(const Duration(days: 7)),
      end: now,
    );

    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      initialDateRange: initialRange,
      helpText: 'Select date range to delete',
    );

    if (!mounted) return;
    if (range == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete selected range?'),
          content: Text(
            'This will permanently delete readings from:\n'
            '${_formatDate(range.start)} → ${_formatDate(range.end)}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    if (confirmed != true) return;

    setState(() => _isDeleting = true);
    try {
      final deleted = await _supabaseService.deleteReadingsInRange(
        start: range.start,
        end: range.end,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted $deleted rows in selected range.'),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Color(0xFF64748B), // slate-500
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.5),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE2E8F0).withValues(alpha: 0.2), // slate-200
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFE0F2FE), // sky-100
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 20,
          color: const Color(0xFF0EA5E9), // sky-500
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1E293B), // slate-800
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF64748B), // slate-500
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: const Color(0xFF0EA5E9), // sky-500
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFE0F2FE), // sky-100
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 20,
          color: const Color(0xFF0EA5E9), // sky-500
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1E293B), // slate-800
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF64748B), // slate-500
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: Color(0xFF64748B),
      ),
      onTap: onTap,
    );
  }
}
