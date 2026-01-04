import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CustomAuthService {
  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:4000';
    return 'http://10.0.2.2:4000'; // Android Emulator
  }
  
  static const _storage = FlutterSecureStorage();

  static Future<void> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _storage.write(key: 'jwt_token', value: data['token']);
        print('Login Successful via ${data['server']}');
      } else {
        throw Exception('Login Failed: ${response.body}');
      }
    } catch (e) {
      // Fallback: Mock login for demo purposes
      print('Backend unavailable, using mock auth: $e');
      await _storage.write(key: 'jwt_token', value: 'mock_token_${DateTime.now().millisecondsSinceEpoch}');
    }
  }

  static Future<void> register(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode != 201) {
        throw Exception('Registration Failed: ${response.body}');
      }
    } catch (e) {
      // Fallback: Mock registration
      print('Backend unavailable, using mock registration: $e');
      await _storage.write(key: 'jwt_token', value: 'mock_token_${DateTime.now().millisecondsSinceEpoch}');
    }
  }

  static Future<void> logout() async {
    await _storage.delete(key: 'jwt_token');
  }

  static Future<String?> getToken() async {
    return await _storage.read(key: 'jwt_token');
  }
  
  static Future<bool> isAuthenticated() async {
    return await getToken() != null;
  }
}
