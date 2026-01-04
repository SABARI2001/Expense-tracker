import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/subscription.dart';

class SubscriptionService {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  // Cache for subscription tier
  SubscriptionTier? _cachedTier;
  String? _cachedUserId;
  DateTime? _cacheTime;
  static const _cacheDuration = Duration(minutes: 5);

  /// Fetch user subscription tier from Supabase
  Future<SubscriptionTier> getUserTier(String userId) async {
    // Return cached tier if valid
    if (_cachedTier != null && 
        _cachedUserId == userId && 
        _cacheTime != null &&
        DateTime.now().difference(_cacheTime!) < _cacheDuration) {
      return _cachedTier!;
    }

    try {
      final response = await _supabase
          .from('subscriptions')
          .select('tier, expires_at')
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        // No subscription found, return free tier
        _updateCache(userId, SubscriptionTier.free);
        return SubscriptionTier.free;
      }

      final tierString = response['tier'] as String;
      final expiresAt = response['expires_at'] != null 
          ? DateTime.parse(response['expires_at'] as String)
          : null;

      // Check if subscription is expired
      if (expiresAt != null && expiresAt.isBefore(DateTime.now())) {
        _updateCache(userId, SubscriptionTier.free);
        return SubscriptionTier.free;
      }

      final tier = _parseTier(tierString);
      _updateCache(userId, tier);
      return tier;
    } catch (e) {
      print('Error fetching subscription tier: $e');
      // Return free tier on error
      return SubscriptionTier.free;
    }
  }

  /// Check if user has premium access
  Future<bool> isPremium(String userId) async {
    final tier = await getUserTier(userId);
    return tier == SubscriptionTier.premium;
  }

  /// Check if subscription is expired
  Future<bool> isExpired(String userId) async {
    try {
      final response = await _supabase
          .from('subscriptions')
          .select('expires_at')
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null || response['expires_at'] == null) {
        return false;
      }

      final expiresAt = DateTime.parse(response['expires_at'] as String);
      return expiresAt.isBefore(DateTime.now());
    } catch (e) {
      print('Error checking subscription expiry: $e');
      return false;
    }
  }

  /// Get subscription expiry date
  Future<DateTime?> getExpiryDate(String userId) async {
    try {
      final response = await _supabase
          .from('subscriptions')
          .select('expires_at')
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null || response['expires_at'] == null) {
        return null;
      }

      return DateTime.parse(response['expires_at'] as String);
    } catch (e) {
      print('Error fetching expiry date: $e');
      return null;
    }
  }

  /// Clear cache (useful after subscription changes)
  void clearCache() {
    _cachedTier = null;
    _cachedUserId = null;
    _cacheTime = null;
  }

  /// Update cache
  void _updateCache(String userId, SubscriptionTier tier) {
    _cachedUserId = userId;
    _cachedTier = tier;
    _cacheTime = DateTime.now();
  }

  /// Parse tier string to enum
  SubscriptionTier _parseTier(String tierString) {
    switch (tierString.toLowerCase()) {
      case 'premium':
        return SubscriptionTier.premium;
      case 'free':
      default:
        return SubscriptionTier.free;
    }
  }
}
