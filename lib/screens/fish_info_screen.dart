import 'package:flutter/material.dart';

class FishInfoScreen extends StatefulWidget {
  const FishInfoScreen({super.key});

  @override
  State<FishInfoScreen> createState() => _FishInfoScreenState();
}

class _FishInfoScreenState extends State<FishInfoScreen> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Red Tilapia Water Quality Guide'),
        elevation: 2,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                      'Optimal water quality parameters for Malaysia freshwater ponds',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Total Dissolved Solids (TDS) / Conductivity',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const Text(
          'Conductivity (μs/cm) acts as a proxy for total ionic content. It\'s critical for monitoring water quality.',
          style: TextStyle(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 20),

        // Best Range
        _buildRangeCard(
          icon: '✓',
          category: 'Best (Optimal)',
          value: '450 – 750 μs/cm',
          color: Colors.green,
          description:
              'Range associated with optimal conditions for tilapia farming. Stable ionic balance supports healthy growth.',
        ),
        const SizedBox(height: 12),

        // Mid Range
        _buildRangeCard(
          icon: '⚠',
          category: 'Mid (Sub-optimal)',
          value: '200 – 450 μs/cm',
          color: Colors.orange,
          description:
              'Acceptable tolerance but potentially suboptimal. Monitor closely and make gradual adjustments.',
        ),
        const SizedBox(height: 12),

        // Risky Range
        _buildRangeCard(
          icon: '✗',
          category: 'Risky (Poor)',
          value: '> 750 or < 200 μs/cm',
          color: Colors.red,
          description:
              'Poor water quality parameters. Indicates instability in the pond system. Immediate action required.',
        ),
        const SizedBox(height: 16),
        const Text(
          '💡 Note: TDS and Conductivity are related. If conductivity is outside optimal range, check for mineral imbalance.',
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
