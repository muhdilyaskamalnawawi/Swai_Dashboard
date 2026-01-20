import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/app_config.dart';

class FishInfoScreen extends StatefulWidget {
  const FishInfoScreen({super.key});

  @override
  State<FishInfoScreen> createState() => _FishInfoScreenState();
}

class _FishInfoScreenState extends State<FishInfoScreen> {
  int _selectedTab = 0;

  static const List<_ReferenceItem> _waterQualityReferences = [
    _ReferenceItem(
      title: 'IoT-Based Fish Farm Water Quality Monitoring System',
      doi: '10.3390/s22176700',
      group: _ReferenceGroup.phAndTemperatureOnly,
    ),
    _ReferenceItem(
      title:
          'Monitoring ambient water quality using machine learning and IoT: A review',
      doi: '10.1016/j.jwpe.2025.107664',
      group: _ReferenceGroup.phTdsOrEcAndTemperature,
    ),
    _ReferenceItem(
      title:
          'IoT-enabled effective real-time water quality monitoring method for aquaculture',
      doi: '10.1016/j.mex.2024.102906',
      group: _ReferenceGroup.phAndTemperatureOnly,
    ),
    _ReferenceItem(
      title:
          'An IoT framework for quality analysis of aquatic water data using time-series convolutional neural network',
      doi: '10.1007/s11356-023-27922-1',
      group: _ReferenceGroup.phAndTemperatureOnly,
    ),
    _ReferenceItem(
      title:
          'Improved accuracy in IoT-Based water quality monitoring for aquaculture tanks',
      doi: '10.1016/j.heliyon.2024.e29022',
      group: _ReferenceGroup.phTdsOrEcAndTemperature,
    ),
    _ReferenceItem(
      title:
          'IoT based smart water quality monitoring system (Global Transitions Proceedings)',
      doi: '10.1016/j.gltp.2021.08.062',
      group: _ReferenceGroup.phTdsOrEcAndTemperature,
    ),
    _ReferenceItem(
      title:
          'Water Quality Management Guidelines to Reduce Mortality Rate of Red Tilapia',
      doi: '10.55164/ajstr.v25i4.247049',
      group: _ReferenceGroup.phAndTemperatureOnly,
    ),
    _ReferenceItem(
      title:
          'Designing a Monitoring System and Optimizing Water Quality in Tilapia Farming Ponds',
      doi: '10.12928/biste.v6i1.10090',
      group: _ReferenceGroup.phAndTemperatureOnly,
    ),
    _ReferenceItem(
      title:
          'Effect of environmental factors on growth performance of Nile tilapia (Oreochromis niloticus)',
      doi: '10.1007/s00484-022-02347-6',
      group: _ReferenceGroup.phAndTemperatureOnly,
    ),
    _ReferenceItem(
      title:
          'Effects of different water quality regulators on growth performance of GIFT tilapia',
      doi: '10.1371/journal.pone.0290854',
      group: _ReferenceGroup.phAndTemperatureOnly,
    ),
    _ReferenceItem(
      title: 'An efficient IoT based smart water quality monitoring system',
      doi: '10.1007/s11042-023-14504-z',
      group: _ReferenceGroup.phTdsOrEcAndTemperature,
    ),
    _ReferenceItem(
      title:
          'Endoparasite infestation of red hybrid tilapia (Oreochromis sp.) in relation to water quality',
      doi: '10.1088/1755-1315/1410/1/012031',
      group: _ReferenceGroup.phAndTemperatureOnly,
    ),
  ];

  void _showReferencesSheet(BuildContext context, {String? forSection}) {
    final sectionTitle = (forSection == null || forSection.trim().isEmpty)
        ? 'References'
        : 'References • $forSection';

    final refsAll3 = _waterQualityReferences
        .where((r) => r.group == _ReferenceGroup.phTdsOrEcAndTemperature)
        .toList(growable: false);
    final refsPhTempOnly = _waterQualityReferences
        .where((r) => r.group == _ReferenceGroup.phAndTemperatureOnly)
        .toList(growable: false);

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Back',
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                    Expanded(
                      child: Text(
                        sectionTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Split of research papers by monitored parameters (DOIs).',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final text = _waterQualityReferences
                              .map((r) => r.doiUrl)
                              .join('\n');
                          await Clipboard.setData(ClipboardData(text: text));
                          if (!ctx.mounted) return;
                          Navigator.of(ctx).pop();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Copied DOI links to clipboard')),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 18),
                        label: const Text('Copy all DOI links'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      _ReferenceSection(
                        title: '1) pH + TDS/Conductivity + Temperature',
                        subtitle:
                            'Comprehensive monitoring includes all three parameters (often EC as proxy for TDS).',
                        refs: refsAll3,
                      ),
                      const SizedBox(height: 8),
                      _ReferenceSection(
                        title: '2) pH + Temperature only (no TDS/Conductivity)',
                        subtitle:
                            'Studies measure pH and temperature (often with other parameters like DO), but not TDS/EC.',
                        refs: refsPhTempOnly,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue.shade100, Colors.cyan.shade100],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🐟 Red Tilapia Farming',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Optimal water quality parameters for Red Tilapia',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Tab Selector
              Row(
                children: [
                  _buildTabButton('pH', 0),
                  const SizedBox(width: 8),
                  _buildTabButton('TDS', 1),
                  const SizedBox(width: 8),
                  _buildTabButton('Temperature', 2),
                ],
              ),
              const SizedBox(height: 24),

              // Content based on selected tab
              if (_selectedTab == 0) _buildPHContent(),
              if (_selectedTab == 1) _buildTDSContent(),
              if (_selectedTab == 2) _buildTemperatureContent(),

              const SizedBox(height: 12),

              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () => _showReferencesSheet(context),
                  icon: const Icon(Icons.menu_book, size: 18),
                  label: const Text('References'),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(String label, int index) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: ElevatedButton(
        onPressed: () => setState(() => _selectedTab = index),
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? Colors.blue : Colors.grey.shade200,
          foregroundColor: isSelected ? Colors.white : Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildPHContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Potential Hydrogen (pH)',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const Text(
          'pH measures how acidic or alkaline the water is. Stability is crucial for tilapia health as they are sensitive to water quality changes.',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 20),

        // Best Range
        _buildRangeCard(
          icon: '✓',
          category: 'Best (Optimal)',
          value: '6.5 to 8.5',
          color: Colors.green,
          description:
              'Normal range—maintain this level. Slightly tighter range for Nile tilapia is 7-8. Fish growth and reproduction are optimum.',
        ),
        const SizedBox(height: 12),

        // Mid Range
        _buildRangeCard(
          icon: '⚠',
          category: 'Mid (Sub-optimal)',
          value: '5.0 to 6.5 or 9.0 to 11.0',
          color: Colors.orange,
          description:
              'Exposure to these ranges results in slow growth. Fish can survive in pH 4-6 and 9-10, but production quality is poor.',
        ),
        const SizedBox(height: 12),

        // Risky Range
        _buildRangeCard(
          icon: '✗',
          category: 'Risky (Lethal)',
          value: '< 4 or > 11.0',
          color: Colors.red,
          description:
              'pH < 4 is the Acid death point. pH > 11 is the Alkaline death point. Extreme levels increase mortality rates.',
        ),
      ],
    );
  }

  Widget _buildTDSContent() {
    final tdsThreshold = AppConfig.thresholds['tds']!;
    final safeMin = tdsThreshold['min']!.round();
    final safeMax = tdsThreshold['max']!.round();
    final criticalMin = tdsThreshold['criticalMin']!.round();
    final criticalMax = tdsThreshold['criticalMax']!.round();

    // Keep wording consistent with DashboardScreen metric status logic:
    // - Good: min..max
    // - Caution: outside min/max but not critical
    // - Alert: <= criticalMin or > criticalMax
    final lowCautionFrom = (criticalMin + 1).clamp(0, safeMin);
    final lowCautionTo = (safeMin - 1).clamp(0, safeMin);
    final highCautionFrom = (safeMax + 1).clamp(safeMax, criticalMax);
    final highCautionTo = criticalMax;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Total Dissolved Solids (TDS)',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(
          'This app evaluates TDS in ppm (same thresholds as the Dashboard). Values outside the safe band are shown as yellow (caution) until they hit critical levels.',
          style: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 20),

        // Best Range
        _buildRangeCard(
          icon: '✓',
          category: 'Best (Safe)',
          value: '$safeMin – $safeMax ppm',
          color: Colors.green,
          description:
              'Target band used by the Dashboard. Example: TDS 600 ppm will be flagged as caution (yellow) because it is above $safeMax ppm.',
        ),
        const SizedBox(height: 12),

        // Mid Range
        _buildRangeCard(
          icon: '⚠',
          category: 'Mid (Caution)',
          value: lowCautionFrom <= lowCautionTo
              ? '$lowCautionFrom – $lowCautionTo ppm or $highCautionFrom – $highCautionTo ppm'
              : '$highCautionFrom – $highCautionTo ppm',
          color: Colors.orange,
          description:
              'Outside the safe band ($safeMin–$safeMax ppm), but not yet critical. Monitor closely and adjust gradually to avoid stress and mineral imbalance.',
        ),
        const SizedBox(height: 12),

        // Risky Range
        _buildRangeCard(
          icon: '✗',
          category: 'Risky (Critical)',
          value: '≤ $criticalMin ppm or > $criticalMax ppm',
          color: Colors.red,
          description:
              'Critical thresholds used by the Dashboard alert system. Immediate action required if TDS crosses these limits.',
        ),
        const SizedBox(height: 16),
        const Text(
          '💡 Note: If your sensor outputs Conductivity (EC) in μS/cm, TDS is often estimated as TDS (ppm) ≈ EC × 0.5–0.7 (depends on water composition).',
          style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  Widget _buildTemperatureContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Temperature (°C)',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const Text(
          'Temperature is the most important physical property of water for aquaculture. It influences all chemical and biological processes, metabolism, growth, and reproduction.',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 20),

        // Best Range
        _buildRangeCard(
          icon: '✓',
          category: 'Best (Optimal Growth)',
          value: '25°C to 30°C',
          color: Colors.green,
          description:
              'Highly recommended thermal range for intensive tilapia culture. Provides optimum growth and stable conditions. 29°C is considered ideal.',
        ),
        const SizedBox(height: 12),

        // Mid Range
        _buildRangeCard(
          icon: '⚠',
          category: 'Mid (Tolerated)',
          value: '20°C to 25°C or 30°C to 35°C',
          color: Colors.orange,
          description:
              'Preferred range is 20-35°C. Growth reduces below 20°C. Feeding reduces sharply below 20°C. Monitor for stress.',
        ),
        const SizedBox(height: 12),

        // Risky Range
        _buildRangeCard(
          icon: '✗',
          category: 'Risky (Lethal)',
          value: '< 10°C or > 37°C',
          color: Colors.red,
          description:
              'Death occurs below 10°C. Severe mortality at 12°C. Stress and disease strike at 37-38°C. Extreme action needed.',
        ),
        const SizedBox(height: 16),
        const Text(
          '💡 Analogy: Think of optimal ranges like house thermostat settings. Best = comfort & efficiency. Mid = tolerable but stressful. Risky = system failure.',
          style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  Widget _buildRangeCard({
    required String icon,
    required String category,
    required String value,
    required Color color,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
        borderRadius: BorderRadius.circular(12),
        color: color.withValues(alpha: 0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                icon,
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _ReferenceItem {
  final String title;
  final String doi;
  final _ReferenceGroup group;

  const _ReferenceItem({
    required this.title,
    required this.doi,
    required this.group,
  });

  String get doiUrl => 'https://doi.org/$doi';
}

enum _ReferenceGroup {
  phTdsOrEcAndTemperature,
  phAndTemperatureOnly,
}

class _ReferenceSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<_ReferenceItem> refs;

  const _ReferenceSection({
    required this.title,
    required this.subtitle,
    required this.refs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(subtitle,
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 10),
          ...refs.map(
            (ref) => Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(ref.title, style: const TextStyle(fontSize: 13)),
                  subtitle: SelectableText(
                    ref.doiUrl,
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: IconButton(
                    tooltip: 'Copy DOI',
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: ref.doiUrl));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied DOI link')),
                      );
                    },
                  ),
                ),
                const Divider(height: 1),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
