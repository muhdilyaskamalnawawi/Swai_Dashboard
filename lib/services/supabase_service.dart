import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/sensor_reading.dart';

class SupabaseService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static const String _tableName = 'sensor_readings';

  /// Fetch latest sensor reading
  Future<SensorReading?> getLatestReading() async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select()
          .order('timestamp', ascending: false)
          .limit(1)
          .single();

      return SensorReading.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching latest reading: $e');
      return null;
    }
  }

  /// Fetch sensor history with optional filters
  Future<List<SensorReading>> getHistory({
    int limit = 100,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var query = _supabase.from(_tableName).select();

      if (startDate != null) {
        query = query.gte('timestamp', startDate.toIso8601String());
      }
      if (endDate != null) {
        query = query.lte('timestamp', endDate.toIso8601String());
      }

      final response =
          await query.order('timestamp', ascending: false).limit(limit);

      return (response as List)
          .map((json) => SensorReading.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching history: $e');
      return [];
    }
  }

  /// Insert new sensor reading
  Future<void> insertReading(SensorReading reading) async {
    try {
      await _supabase.from(_tableName).insert(reading.toJson());
    } catch (e) {
      debugPrint('Error inserting reading: $e');
      rethrow;
    }
  }

  /// Update existing reading
  Future<void> updateReading(SensorReading reading) async {
    try {
      await _supabase
          .from(_tableName)
          .update(reading.toJson())
          .eq('id', reading.id);
    } catch (e) {
      debugPrint('Error updating reading: $e');
      rethrow;
    }
  }

  /// Delete reading
  Future<void> deleteReading(String id) async {
    try {
      await _supabase.from(_tableName).delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting reading: $e');
      rethrow;
    }
  }

  /// Listen to real-time updates
  Stream<SensorReading?> getLatestReadingStream() {
    try {
      return _supabase
          .from(_tableName)
          .stream(primaryKey: ['id'])
          .order('timestamp', ascending: false)
          .limit(1)
          .map((data) {
            if (data.isNotEmpty) {
              return SensorReading.fromJson(data.first);
            }
            return null;
          });
    } catch (e) {
      debugPrint('Error setting up real-time stream: $e');
      return Stream.empty();
    }
  }

  /// Get statistics for a date range
  Future<Map<String, dynamic>> getStatistics({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final readings = await getHistory(
        limit: 10000,
        startDate: startDate,
        endDate: endDate,
      );

      if (readings.isEmpty) {
        return {};
      }

      final pHValues = readings.map((r) => r.pH).toList();
      final tempValues = readings.map((r) => r.temp).toList();
      final tdsValues = readings.map((r) => r.tds).toList();

      return {
        'pH': {
          'avg': pHValues.reduce((a, b) => a + b) / pHValues.length,
          'min': pHValues.reduce((a, b) => a < b ? a : b),
          'max': pHValues.reduce((a, b) => a > b ? a : b),
        },
        'temp': {
          'avg': tempValues.reduce((a, b) => a + b) / tempValues.length,
          'min': tempValues.reduce((a, b) => a < b ? a : b),
          'max': tempValues.reduce((a, b) => a > b ? a : b),
        },
        'tds': {
          'avg': tdsValues.reduce((a, b) => a + b) / tdsValues.length,
          'min': tdsValues.reduce((a, b) => a < b ? a : b),
          'max': tdsValues.reduce((a, b) => a > b ? a : b),
        },
      };
    } catch (e) {
      debugPrint('Error calculating statistics: $e');
      return {};
    }
  }
}
