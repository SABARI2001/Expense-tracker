package com.example.expense_tracker

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.expense_tracker/sms"
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Set up SMS channel for reading existing messages
        val smsChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        smsChannel.setMethodCallHandler(SmsChannel(context))
        
        // Set up broadcast receiver for real-time SMS
        SmsBroadcastReceiver.setMethodChannel(smsChannel)
    }
}
