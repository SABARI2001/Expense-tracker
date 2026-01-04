package com.example.expense_tracker

import android.content.Context
import android.net.Uri
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class SmsChannel(private val context: Context) : MethodChannel.MethodCallHandler {
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "getSmsMessages") {
            val messages = getAllSms()
            result.success(messages)
        } else {
            result.notImplemented()
        }
    }

    private fun getAllSms(): List<String> {
        val messages = mutableListOf<String>()
        val uri = Uri.parse("content://sms/inbox")
        val cursor = context.contentResolver.query(uri, null, null, null, null)

        cursor?.use {
            if (it.moveToFirst()) {
                do {
                    val body = it.getString(it.getColumnIndexOrThrow("body"))
                    messages.add(body)
                } while (it.moveToNext())
            }
        }
        return messages
    }
}
