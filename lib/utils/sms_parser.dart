import '../models/expense.dart';

class SmsParser {
  // Regex to capture Amount and Merchant from typical Indian bank SMS
  // Example: "Rs. 1200.00 spent on STARBUCKS using card XX1234..."
  // Example: "Sent Rs. 500.00 to UBER VIA UPI..."
  static final RegExp _amountRegex = RegExp(r'(?:Rs\.?|INR)\s*([\d,]+\.?\d*)', caseSensitive: false);
  static final RegExp _merchantRegex = RegExp(r'(?:at|on|to)\s+([A-Za-z0-9\s]+?)(?:\s+(?:via|using|on|ref|val|ending)|$)', caseSensitive: false);

  static Expense? parse(String message) {
    if (!message.toLowerCase().contains('spent') && !message.toLowerCase().contains('debited') && !message.toLowerCase().contains('sent')) {
      return null;
    }

    final amountMatch = _amountRegex.firstMatch(message);
    final merchantMatch = _merchantRegex.firstMatch(message);

    if (amountMatch != null) {
      String amountStr = amountMatch.group(1)!.replaceAll(',', '');
      double amount = double.tryParse(amountStr) ?? 0.0;
      
      String merchant = merchantMatch?.group(1)?.trim() ?? 'Unknown Merchant';
      
      return Expense(
        amount: amount,
        merchant: merchant,
        category: 'Auto-detected',
        date: DateTime.now(),
      );
    }
    return null;
  }
}
