import 'package:supabase_flutter/supabase_flutter.dart';

class DatabaseHealthService {
  final _client = Supabase.instance.client;

  /// Check database connection health
  Future<Map<String, dynamic>> checkHealth() async {
    try {
      final startTime = DateTime.now();
      
      // Simple ping query
      await _client.from('user_profiles').select('user_id').limit(1);
      
      final latency = DateTime.now().difference(startTime).inMilliseconds;
      
      return {
        'status': 'healthy',
        'latency_ms': latency,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'status': 'error',
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Log connection health
  Future<void> logConnectionHealth(String connectionType, int latencyMs) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return;

      await _client.from('connection_health').insert({
        'user_id': userId,
        'connection_type': connectionType,
        'latency_ms': latencyMs,
      });
    } catch (e) {
      print('Failed to log connection health: $e');
    }
  }

  /// Get database health report
  Future<List<Map<String, dynamic>>> getDatabaseHealthReport() async {
    try {
      final result = await _client.rpc('check_database_health');
      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      print('Failed to get health report: $e');
      return [];
    }
  }

  /// Create user data snapshot (backup)
  Future<String?> createUserSnapshot() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return null;

      final result = await _client.rpc('create_user_snapshot', params: {
        'p_user_id': userId,
      });

      return result as String?;
    } catch (e) {
      print('Failed to create snapshot: $e');
      return null;
    }
  }

  /// Get user engagement metrics
  Future<Map<String, dynamic>?> getUserEngagement() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return null;

      final data = await _client
          .from('user_engagement')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      return data;
    } catch (e) {
      print('Failed to get engagement: $e');
      return null;
    }
  }

  /// Refresh statistics
  Future<void> refreshStatistics() async {
    try {
      await _client.rpc('refresh_user_statistics');
    } catch (e) {
      print('Failed to refresh statistics: $e');
    }
  }
}
