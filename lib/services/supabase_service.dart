import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/sensor_reading.dart';
import 'prediction_service.dart';

class SupabaseService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static const String _tableName = 'sensor_readings';

  DateTime _startOfDayUtc(DateTime date) {
    final local = DateTime(date.year, date.month, date.day);
    return local.toUtc();
  }

  DateTime _endOfDayUtc(DateTime date) {
    final local = DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
    return local.toUtc();
  }

  int _countFromDeleteResponse(dynamic response) {
    if (response is List) return response.length;
    return 0;
  }

  Map<String, dynamic> _toDbPayload(SensorReading reading) {
    final payload = reading.toJson();
    payload.removeWhere((key, value) => value == null);
    return payload;
  }

  bool _isMissingColumnError(PostgrestException e, String column) {
    if (e.code != 'PGRST204') return false;
    final msg = e.message.toLowerCase();
    return msg.contains(column.toLowerCase());
  }

  /// Fetch latest sensor reading
  Future<SensorReading?> getLatestReading() async {
    try {
      debugPrint('🔍 Querying Supabase for latest reading...');

      Map<String, dynamic> response;
      try {
        // Prefer DB-generated insert time to avoid devices sending bad timestamps.
        response = await _supabase
            .from(_tableName)
            .select()
            .order('created_at', ascending: false)
            .limit(1)
            .single();
      } on PostgrestException catch (e) {
        if (_isMissingColumnError(e, 'created_at')) {
          response = await _supabase
              .from(_tableName)
              .select()
              .order('timestamp', ascending: false)
              .limit(1)
              .single();
        } else {
          rethrow;
        }
      }

      final reading = SensorReading.fromJson(response);
      debugPrint('✅ Got reading from DB: pH=${reading.pH}');
      return reading;
    } on PostgrestException catch (e) {
      debugPrint('❌ Supabase error: ${e.message} (code: ${e.code})');
      if (e.code == 'PGRST116') {
        debugPrint('⚠️ No data in database yet');
        return null;
      }
      rethrow;
    } catch (e) {
      debugPrint('❌ Error fetching latest reading: $e');
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

      dynamic response;
      try {
        response =
            await query.order('created_at', ascending: false).limit(limit);
      } on PostgrestException catch (e) {
        if (_isMissingColumnError(e, 'created_at')) {
          response =
              await query.order('timestamp', ascending: false).limit(limit);
        } else {
          rethrow;
        }
      }

      return (response as List)
          .map((json) => SensorReading.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching history: $e');
      return [];
    }
  }

  /// Fetch history for the last [days] days using UTC and ISO8601 to avoid gaps
  Future<List<SensorReading>> getHistoryByDays(int days) async {
    final since = DateTime.now().toUtc().subtract(Duration(days: days));
    return getHistory(startDate: since, limit: 1000);
  }

  /// Insert new sensor reading
  Future<void> insertReading(SensorReading reading) async {
    try {
      await _supabase.from(_tableName).insert(_toDbPayload(reading));
    } catch (e) {
      debugPrint('Error inserting reading: $e');
      rethrow;
    }
  }

  /// Insert a reading after running local ML to attach prediction + confidence
  Future<void> insertReadingWithPrediction(SensorReading reading) async {
    try {
      final result =
          await PredictionService.getPredictionWithConfidence(reading);
      final payload = _toDbPayload(reading)
        ..['prediction'] = result.label
        ..['confidence'] = result.confidence;

      try {
        await _supabase.from(_tableName).insert(payload);
      } on PostgrestException catch (e) {
        if (_isMissingColumnError(e, 'confidence')) {
          final fallback = Map<String, dynamic>.from(payload)
            ..remove('confidence');
          await _supabase.from(_tableName).insert(fallback);
        } else {
          rethrow;
        }
      }
      debugPrint('✅ Inserted reading with prediction and confidence');
    } catch (e) {
      debugPrint('Error inserting reading with prediction: $e');
      rethrow;
    }
  }

  /// Update existing reading
  Future<void> updateReading(SensorReading reading) async {
    try {
      final payload = _toDbPayload(reading);
      try {
        await _supabase.from(_tableName).update(payload).eq('id', reading.id);
      } on PostgrestException catch (e) {
        if (_isMissingColumnError(e, 'confidence')) {
          final fallback = Map<String, dynamic>.from(payload)
            ..remove('confidence');
          await _supabase
              .from(_tableName)
              .update(fallback)
              .eq('id', reading.id);
        } else {
          rethrow;
        }
      }
    } catch (e) {
      debugPrint('Error updating reading: $e');
      rethrow;
    }
  }

  /// Update only enrichment fields (ML/AI) for an existing row.
  ///
  /// This avoids accidentally overwriting raw sensor values (ph/temp/tds)
  /// when the app is only trying to persist prediction/recommendation.
  Future<void> updateReadingEnrichment({
    required String id,
    String? prediction,
    double? confidence,
    String? recommendation,
    bool? isAlert,
  }) async {
    try {
      final payload = <String, dynamic>{
        if (prediction != null) 'prediction': prediction,
        if (confidence != null) 'confidence': confidence,
        if (recommendation != null) 'recommendation': recommendation,
        if (isAlert != null) 'is_alert': isAlert,
      };

      if (payload.isEmpty) return;

      try {
        await _supabase.from(_tableName).update(payload).eq('id', id);
      } on PostgrestException catch (e) {
        if (_isMissingColumnError(e, 'confidence')) {
          final fallback = Map<String, dynamic>.from(payload)
            ..remove('confidence');
          await _supabase.from(_tableName).update(fallback).eq('id', id);
        } else {
          rethrow;
        }
      }
    } catch (e) {
      debugPrint('Error updating reading enrichment: $e');
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

  /// Delete all readings in the table.
  ///
  /// WARNING: This permanently removes all sensor history.
  /// Returns the number of rows deleted when available.
  Future<int> deleteAllReadings() async {
    try {
      final response = await _supabase.from(_tableName).delete().select('id');
      return _countFromDeleteResponse(response);
    } catch (e) {
      debugPrint('Error deleting all readings: $e');
      rethrow;
    }
  }

  /// Delete readings whose `timestamp` is between [start] and [end] (inclusive).
  /// Returns the number of rows deleted when available.
  Future<int> deleteReadingsInRange({
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final startUtc = _startOfDayUtc(start);
      final endUtc = _endOfDayUtc(end);

      final normalizedStart = startUtc.isBefore(endUtc) ? startUtc : endUtc;
      final normalizedEnd = startUtc.isBefore(endUtc) ? endUtc : startUtc;

      final response = await _supabase
          .from(_tableName)
          .delete()
          .gte('timestamp', normalizedStart.toIso8601String())
          .lte('timestamp', normalizedEnd.toIso8601String())
          .select('id');
      return _countFromDeleteResponse(response);
    } catch (e) {
      debugPrint('Error deleting readings in range: $e');
      rethrow;
    }
  }

  /// Delete readings with `timestamp` older than [cutoff] (exclusive).
  /// Returns the number of rows deleted when available.
  Future<int> deleteReadingsBefore(DateTime cutoff) async {
    try {
      final response = await _supabase
          .from(_tableName)
          .delete()
          .lt('timestamp', cutoff.toUtc().toIso8601String())
          .select('id');
      return _countFromDeleteResponse(response);
    } catch (e) {
      debugPrint('Error deleting readings before cutoff: $e');
      rethrow;
    }
  }

  /// Listen to real-time updates
  Stream<SensorReading?> getLatestReadingStream() {
    try {
      return _supabase
          .from(_tableName)
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          // Buffer multiple rows because `.limit(1)` can get stuck on older data
          // depending on how the stream applies realtime changes.
          .limit(50)
          .map((rows) {
            if (rows.isEmpty) return null;

            // Rows are already ordered by created_at DESC.
            return SensorReading.fromJson(rows.first);
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
