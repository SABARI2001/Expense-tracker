import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SessionGuard {
  static final _client = Supabase.instance.client;

  static Future<bool> isLoggedIn() async {
    return _client.auth.currentUser != null;
  }

  static Future<bool> isAdmin() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return false;
      
      final response = await _client
          .from('user_roles')
          .select('role')
          .eq('user_id', user.id)
          .maybeSingle();
      
      return response?['role'] == 'admin';
    } catch (e) {
      return false;
    }
  }

  static Future<bool> isPremium() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return false;
      
      final response = await _client
          .from('subscriptions')
          .select('tier')
          .eq('user_id', user.id)
          .maybeSingle();
      
      return response?['tier'] == 'premium';
    } catch (e) {
      return false;
    }
  }
}
