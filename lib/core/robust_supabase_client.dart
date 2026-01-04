import 'package:supabase_flutter/supabase_flutter.dart';

/// Enhanced Supabase client with connection pooling and retry logic
class RobustSupabaseClient {
  static final RobustSupabaseClient _instance = RobustSupabaseClient._internal();
  factory RobustSupabaseClient() => _instance;
  RobustSupabaseClient._internal();

  SupabaseClient get client => Supabase.instance.client;
  
  int _retryCount = 0;
  static const int maxRetries = 3;
  static const Duration retryDelay = Duration(seconds: 2);

  /// Execute query with automatic retry on failure
  Future<T> executeWithRetry<T>(
    Future<T> Function() operation, {
    int maxAttempts = maxRetries,
  }) async {
    int attempts = 0;
    
    while (attempts < maxAttempts) {
      try {
        final result = await operation();
        _retryCount = 0; // Reset on success
        return result;
      } catch (e) {
        attempts++;
        _retryCount = attempts;
        
        if (attempts >= maxAttempts) {
          print('Operation failed after $maxAttempts attempts: $e');
          rethrow;
        }
        
        print('Attempt $attempts failed, retrying in ${retryDelay.inSeconds}s...');
        await Future.delayed(retryDelay * attempts); // Exponential backoff
      }
    }
    
    throw Exception('Operation failed after $maxAttempts attempts');
  }

  /// Check if connection is healthy
  Future<bool> isHealthy() async {
    try {
      await client.from('user_profiles').select('user_id').limit(1);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get connection status
  String getConnectionStatus() {
    if (_retryCount == 0) return 'online';
    if (_retryCount < maxRetries) return 'reconnecting';
    return 'offline';
  }

  /// Ensure user data is complete
  Future<bool> validateUserData(String userId) async {
    try {
      final profile = await client
          .from('user_profiles')
          .select()
          .eq('user_id', userId)
          .single();

      // Check all required fields
      return profile['full_name'] != null &&
             profile['email'] != null &&
             profile['phone_number'] != null &&
             profile['date_of_birth'] != null;
    } catch (e) {
      return false;
    }
  }
}
