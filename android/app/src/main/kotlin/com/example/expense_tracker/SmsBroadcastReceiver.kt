package com.example.expense_tracker

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.telephony.SmsMessage
import io.flutter.plugin.common.MethodChannel
import java.util.regex.Pattern

class SmsBroadcastReceiver : BroadcastReceiver() {
    companion object {
        private const val CHANNEL_NAME = "com.example.expense_tracker/sms"
        private var methodChannel: MethodChannel? = null

        fun setMethodChannel(channel: MethodChannel) {
            methodChannel = channel
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            
            for (smsMessage in messages) {
                val sender = smsMessage.displayOriginatingAddress
                val messageBody = smsMessage.messageBody
                
                // Check if it's a bank/payment SMS
                if (isPaymentSMS(sender, messageBody)) {
                    val expenseData = parseExpense(messageBody, sender)
                    
                    // Send to Flutter
                    methodChannel?.invokeMethod("onSmsReceived", expenseData)
                }
            }
        }
    }

    private fun isPaymentSMS(sender: String, message: String): Boolean {
        val bankKeywords = listOf(
            "debited", "debit", "spent", "paid", "payment",
            "upi", "imps", "neft", "rtgs", "transaction"
        )
        
        val bankSenders = listOf(
            "HDFCBK", "ICICIB", "SBIIN", "AXISBK", "KOTAKB",
            "PNBSMS", "BOISMS", "CBSSBI", "UNIONB", "INDUSB",
            "YESBNK", "IDFCFB", "SCBANK", "CITIBK", "HSBCIN",
            "PAYTM", "GOOGLEPAY", "PHONEPE", "AMAZONPAY"
        )
        
        val messageLower = message.lowercase()
        val senderUpper = sender.uppercase()
        
        return bankKeywords.any { messageLower.contains(it) } ||
               bankSenders.any { senderUpper.contains(it) }
    }

    private fun parseExpense(message: String, sender: String): Map<String, Any> {
        val data = mutableMapOf<String, Any>()
        data["raw_message"] = message
        data["sender"] = sender
        data["timestamp"] = System.currentTimeMillis()

        // Extract amount
        val amountPatterns = listOf(
            "(?:rs\\.?|inr|₹)\\s*([0-9,]+\\.?[0-9]*)",
            "(?:debited|spent|paid).*?(?:rs\\.?|inr|₹)?\\s*([0-9,]+\\.?[0-9]*)",
            "(?:amount|amt).*?(?:rs\\.?|inr|₹)?\\s*([0-9,]+\\.?[0-9]*)"
        )

        for (pattern in amountPatterns) {
            val matcher = Pattern.compile(pattern, Pattern.CASE_INSENSITIVE).matcher(message)
            if (matcher.find()) {
                val amountStr = matcher.group(1)?.replace(",", "") ?: "0"
                data["amount"] = amountStr.toDoubleOrNull() ?: 0.0
                break
            }
        }

        // Extract merchant
        val merchantPatterns = listOf(
            "(?:at|to|for)\\s+([A-Za-z0-9\\s&.-]+?)(?:\\s+on|\\.|,|$)",
            "(?:merchant|payee)\\s*:?\\s*([A-Za-z0-9\\s&.-]+?)(?:\\s+on|\\.|,|$)",
            "upi-([A-Za-z0-9\\s&.-]+?)(?:@|\\s)"
        )

        for (pattern in merchantPatterns) {
            val matcher = Pattern.compile(pattern, Pattern.CASE_INSENSITIVE).matcher(message)
            if (matcher.find()) {
                data["merchant"] = matcher.group(1)?.trim() ?: "Unknown"
                break
            }
        }

        if (!data.containsKey("merchant")) {
            data["merchant"] = "Unknown Merchant"
        }

        return data
    }
}
