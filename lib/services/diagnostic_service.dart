import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Diagnostic helper to verify Supabase connection and data
class DiagnosticService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Run full diagnostic check
  static Future<DiagnosticResult> runDiagnostics() async {
    debugPrint('🧪 Starting diagnostics...');

    final result = DiagnosticResult();

    // Test 1: Can connect to Supabase
    result.supabaseConnected = await _testSupabaseConnection();

    // Test 2: Table exists and has data
    if (result.supabaseConnected) {
      result.tableHasData = await _testTableHasData();
      result.rowCount = await _getRowCount();
    }

    // Test 3: Can fetch latest reading
    if (result.supabaseConnected && result.tableHasData) {
      result.canFetchData = await _testFetchLatestReading();
    }

    // Test 4: Stream connection
    result.streamConnected = await _testStreamConnection();

    debugPrint('📊 Diagnostic Results:');
    debugPrint('  Supabase Connected: ${result.supabaseConnected ? "✅" : "❌"}');
    debugPrint('  Table Has Data: ${result.tableHasData ? "✅" : "❌"}');
    debugPrint('  Row Count: ${result.rowCount}');
    debugPrint('  Can Fetch Data: ${result.canFetchData ? "✅" : "❌"}');
    debugPrint('  Stream Connected: ${result.streamConnected ? "✅" : "❌"}');

    return result;
  }

  /// Test basic Supabase connection
  static Future<bool> _testSupabaseConnection() async {
    try {
      debugPrint('🔌 Testing Supabase connection...');
      await _supabase.from('sensor_readings').select().limit(1);
      debugPrint('✅ Supabase connection OK');
      return true;
    } catch (e) {
      debugPrint('❌ Supabase connection failed: $e');
      return false;
    }
  }

  /// Check if table has any data
  static Future<bool> _testTableHasData() async {
    try {
      debugPrint('📋 Checking if table has data...');
      final response =
          await _supabase.from('sensor_readings').select().limit(1);

      final hasData = (response as List).isNotEmpty;
      if (hasData) {
        debugPrint('✅ Table has data');
      } else {
        debugPrint('⚠️ Table is empty - no readings yet');
      }
      return hasData;
    } catch (e) {
      debugPrint('❌ Error checking table: $e');
      return false;
    }
  }

  /// Get total row count
  static Future<int> _getRowCount() async {
    try {
      debugPrint('🔢 Counting total rows...');

      // Prefer HEAD+count request (no row payload).
      final count = await _supabase.from('sensor_readings').count();
      debugPrint('✅ Row count: $count');
      return count;
    } catch (e) {
      debugPrint('❌ Error getting row count: $e');
      return 0;
    }
  }

  /// Test fetching latest reading
  static Future<bool> _testFetchLatestReading() async {
    try {
      debugPrint('🔍 Testing fetch latest reading...');
      final response = await _supabase
          .from('sensor_readings')
          .select()
          .order('timestamp', ascending: false)
          .limit(1)
          .single();

      debugPrint('✅ Got reading: $response');
      return true;
    } catch (e) {
      debugPrint('❌ Error fetching reading: $e');
      return false;
    }
  }

  /// Test real-time stream
  static Future<bool> _testStreamConnection() async {
    try {
      debugPrint('📡 Testing stream connection...');

      final stream =
          _supabase.from('sensor_readings').stream(primaryKey: ['id']).limit(1);

      final firstEvent = await stream.first.timeout(
        const Duration(seconds: 5),
        onTimeout: () => [],
      );

      if (firstEvent.isNotEmpty) {
        debugPrint('✅ Stream connection OK');
        return true;
      } else {
        debugPrint('⚠️ Stream received empty data');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Stream connection failed: $e');
      return false;
    }
  }

  /// Print diagnostic report
  static void printReport(DiagnosticResult result) {
    debugPrint('\n📋 ========== DIAGNOSTIC REPORT ==========');
    debugPrint(
        'Supabase Connection: ${result.supabaseConnected ? "✅ PASS" : "❌ FAIL"}');
    debugPrint('Table Has Data: ${result.tableHasData ? "✅ PASS" : "❌ FAIL"}');
    debugPrint('Row Count: ${result.rowCount}');
    debugPrint('Can Fetch Data: ${result.canFetchData ? "✅ PASS" : "❌ FAIL"}');
    debugPrint(
        'Stream Connected: ${result.streamConnected ? "✅ PASS" : "❌ FAIL"}');
    debugPrint('=========================================\n');

    if (result.allTestsPassed) {
      debugPrint('✅ All checks passed! App should display data.');
    } else {
      debugPrint('❌ Some checks failed. See above for details.');
      if (!result.supabaseConnected) {
        debugPrint('   → Check network connection and Supabase credentials');
      }
      if (!result.tableHasData) {
        debugPrint('   → Send test data from Arduino/backend first');
      }
    }
  }
}

class DiagnosticResult {
  bool supabaseConnected = false;
  bool tableHasData = false;
  int rowCount = 0;
  bool canFetchData = false;
  bool streamConnected = false;

  bool get allTestsPassed => supabaseConnected && tableHasData && canFetchData;
}
