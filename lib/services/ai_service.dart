import 'package:supabase_flutter/supabase_flutter.dart';

class AIService {
  final _client = Supabase.instance.client;

  Future<String> getInsights(List<Map<String, dynamic>> expenses) async {
    try {
      final response = await _client.functions.invoke(
        'expense_insights',
        body: {'expenses': expenses},
      );

      if (response.data != null && response.data['insights'] != null) {
        return response.data['insights'];
      }
      
      return _generateFallbackInsights(expenses);
    } catch (e) {
      print('AI Service Error: $e');
      return _generateFallbackInsights(expenses);
    }
  }

  String _generateFallbackInsights(List<Map<String, dynamic>> expenses) {
    if (expenses.isEmpty) {
      return 'Start tracking your expenses to get personalized insights!';
    }

    final total = expenses.fold(0.0, (sum, e) => sum + (e['amount'] as double));
    final avgPerTransaction = total / expenses.length;
    
    // Category analysis
    final categoryTotals = <String, double>{};
    for (var expense in expenses) {
      final category = expense['category'] as String;
      final amount = expense['amount'] as double;
      categoryTotals[category] = (categoryTotals[category] ?? 0) + amount;
    }
    
    final topCategory = categoryTotals.entries.reduce((a, b) => a.value > b.value ? a : b);
    final topCategoryPercent = (topCategory.value / total * 100).toStringAsFixed(0);

    return '''
📊 Spending Analysis:
• Total: \$${total.toStringAsFixed(2)} across ${expenses.length} transactions
• Average per transaction: \$${avgPerTransaction.toStringAsFixed(2)}
• Top category: ${topCategory.key} (${topCategoryPercent}% of spending)

💡 Insights:
${_getSmartRecommendation(total, topCategory.key, categoryTotals)}
''';
  }

  String _getSmartRecommendation(double total, String topCategory, Map<String, double> categories) {
    if (total > 1000) {
      return '• Consider setting a monthly budget to track your spending goals\n• Your ${topCategory.toLowerCase()} expenses are significant - look for savings opportunities';
    } else if (categories.length > 5) {
      return '• You\'re spending across many categories - great diversity!\n• Focus on tracking your top 3 categories for better control';
    } else {
      return '• Your spending is well-controlled\n• Keep up the good tracking habits!';
    }
  }

  static void runDailyInsights() {
    print("Running daily insights...");
  }
}
