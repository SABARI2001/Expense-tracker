import 'package:flutter/services.dart';
import '../utils/sms_parser.dart';

class SmsService {
  static const platform = MethodChannel('com.example.expense_tracker/sms');

  Future<List<String>> readSmsMessages() async {
    try {
      // Expecting a List<Object?> which we cast to List<dynamic> then String
      final List<dynamic> messages = await platform.invokeMethod('getSmsMessages');
      return messages.cast<String>();
    } on PlatformException catch (e) {
      print("Failed to get SMS: '${e.message}'.");
      return [];
    }
  }
}
