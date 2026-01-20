class SensorReading {
  final String id;
  final double pH;
  final double temp;
  final double tds;
  final String? prediction;
  final double? confidence;
  final String? recommendation;
  final DateTime timestamp;
  final bool isAlert;

  SensorReading({
    required this.id,
    required this.pH,
    required this.temp,
    required this.tds,
    this.prediction,
    this.confidence,
    this.recommendation,
    required this.timestamp,
    this.isAlert = false,
  });

  // Convert to JSON for database operations
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ph': pH,
      'temp': temp,
      'tds': tds,
      'prediction': prediction,
      'confidence': confidence,
      'recommendation': recommendation,
      'timestamp': timestamp.toIso8601String(),
      'is_alert': isAlert,
    };
  }

  // Create from JSON (Supabase response)
  factory SensorReading.fromJson(Map<String, dynamic> json) {
    double asDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value.trim()) ?? 0.0;
      return 0.0;
    }

    final phRaw = json['pH'] ?? json['ph'] ?? json['PH'];
    final tempRaw = json['temp'] ?? json['temperature'] ?? json['Temp'];
    final tdsRaw = json['tds'] ??
        json['TDS'] ??
        json['tds_value'] ??
        json['tdsPpm'] ??
        json['tds_ppm'] ??
        json['ec'] ??
        json['EC'] ??
        json['conductivity'] ??
        json['Conductivity'];

    return SensorReading(
      id: json['id'] ?? '',
      pH: asDouble(phRaw),
      temp: asDouble(tempRaw),
      tds: asDouble(tdsRaw),
      prediction: (json['prediction'] != null &&
              json['prediction'].toString().trim().isNotEmpty)
          ? json['prediction']
          : null,
      confidence: json['confidence'] != null
          ? (json['confidence'] as num).toDouble()
          : null,
      recommendation: (json['recommendation'] != null &&
              json['recommendation'].toString().trim().isNotEmpty)
          ? json['recommendation']
          : null,
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      isAlert: json['is_alert'] == true, // Only true if explicitly true
    );
  }

  // Create copy with modifications
  SensorReading copyWith({
    String? id,
    double? pH,
    double? temp,
    double? tds,
    String? prediction,
    double? confidence,
    String? recommendation,
    DateTime? timestamp,
    bool? isAlert,
  }) {
    return SensorReading(
      id: id ?? this.id,
      pH: pH ?? this.pH,
      temp: temp ?? this.temp,
      tds: tds ?? this.tds,
      prediction: prediction ?? this.prediction,
      confidence: confidence ?? this.confidence,
      recommendation: recommendation ?? this.recommendation,
      timestamp: timestamp ?? this.timestamp,
      isAlert: isAlert ?? this.isAlert,
    );
  }

  @override
  String toString() =>
      'SensorReading(pH: $pH, temp: $temp, tds: $tds, prediction: $prediction, confidence: $confidence, timestamp: $timestamp, isAlert: $isAlert)';
}
