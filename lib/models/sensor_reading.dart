class SensorReading {
  final String id;
  final double pH;
  final double temp;
  final double tds;
  final String? prediction;
  final String? recommendation;
  final DateTime timestamp;
  final bool isAlert;

  SensorReading({
    required this.id,
    required this.pH,
    required this.temp,
    required this.tds,
    this.prediction,
    this.recommendation,
    required this.timestamp,
    this.isAlert = false,
  });

  // Convert to JSON for database operations
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pH': pH,
      'temp': temp,
      'tds': tds,
      'prediction': prediction,
      'recommendation': recommendation,
      'timestamp': timestamp.toIso8601String(),
      'is_alert': isAlert,
    };
  }

  // Create from JSON (Supabase response)
  factory SensorReading.fromJson(Map<String, dynamic> json) {
    return SensorReading(
      id: json['id'] ?? '',
      pH: (json['pH'] ?? json['ph'] ?? 0.0).toDouble(),
      temp: (json['temp'] ?? json['temperature'] ?? 0.0).toDouble(),
      tds: (json['tds'] ?? 0.0).toDouble(),
      prediction: json['prediction'] ?? '',
      recommendation: json['recommendation'] ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      isAlert: json['is_alert'] ?? false,
    );
  }

  // Create copy with modifications
  SensorReading copyWith({
    String? id,
    double? pH,
    double? temp,
    double? tds,
    String? prediction,
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
      recommendation: recommendation ?? this.recommendation,
      timestamp: timestamp ?? this.timestamp,
      isAlert: isAlert ?? this.isAlert,
    );
  }

  @override
  String toString() =>
      'SensorReading(pH: $pH, temp: $temp, tds: $tds, timestamp: $timestamp, isAlert: $isAlert)';
}
