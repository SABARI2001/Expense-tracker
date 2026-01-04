package com.example.expense_tracker

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.telephony.SmsMessage
import android.os.Bundle
import io.flutter.plugin.common.MethodChannel

class SmsReceiver : BroadcastReceiver() {
    companion object {
        private const val CHANNEL = "com.example.expense_tracker/sms"
        var methodChannel: MethodChannel? = null
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == "android.provider.Telephony.SMS_RECEIVED") {
            val bundle: Bundle? = intent.extras
            if (bundle != null) {
                try {
                    val pdus = bundle.get("pdus") as Array<*>
                    val messages = arrayOfNulls<SmsMessage>(pdus.size)
                    
                    for (i in pdus.indices) {
                        messages[i] = SmsMessage.createFromPdu(pdus[i] as ByteArray)
                    }
                    
                    // Concatenate message body if split
                    val messageBody = StringBuilder()
                    for (message in messages) {
                        messageBody.append(message?.messageBody ?: "")
                    }
                    
                    val sender = messages[0]?.originatingAddress ?: ""
                    val body = messageBody.toString()
                    
                    // Check if it's a bank transaction SMS
                    if (isBankTransaction(body)) {
                        // Send to Flutter via MethodChannel
                        methodChannel?.invokeMethod("onSmsReceived", mapOf(
                            "sender" to sender,
                            "body" to body,
                            "timestamp" to System.currentTimeMillis()
                        ))
                    }
                } catch (e: Exception) {
                    e.printStackTrace()
                }
            }
        }
    }
    
    private fun isBankTransaction(message: String): Boolean {
        val lowerMessage = message.toLowerCase()
        
        // Check for common bank transaction keywords
        val transactionKeywords = listOf(
            "debited", "credited", "spent", "sent", "received",
            "withdrawn", "deposited", "paid", "transaction",
            "upi", "card", "account", "balance"
        )
        
        // Check for currency indicators
        val currencyIndicators = listOf("rs.", "rs ", "inr", "₹")
        
        val hasTransactionKeyword = transactionKeywords.any { lowerMessage.contains(it) }
        val hasCurrency = currencyIndicators.any { lowerMessage.contains(it) }
        
        return hasTransactionKeyword && hasCurrency
    }
}
