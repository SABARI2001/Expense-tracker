import 'package:supabase_flutter/supabase_flutter.dart';

class BudgetService {
  final _client = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getBudgets() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final now = DateTime.now();
    final data = await _client
        .from('budgets')
        .select()
        .eq('user_id', userId)
        .eq('month', now.month)
        .eq('year', now.year);

    return List<Map<String, dynamic>>.from(data);
  }

  Future<void> createBudget(String category, double monthlyLimit) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    final now = DateTime.now();
    await _client.from('budgets').insert({
      'user_id': userId,
      'category': category,
      'monthly_limit': monthlyLimit,
      'month': now.month,
      'year': now.year,
    });
  }

  Future<void> updateBudget(String budgetId, double newLimit) async {
    await _client
        .from('budgets')
        .update({'monthly_limit': newLimit})
        .eq('id', budgetId);
  }

  Future<void> deleteBudget(String budgetId) async {
    await _client.from('budgets').delete().eq('id', budgetId);
  }

  Future<Map<String, dynamic>> getBudgetSummary() async {
    final budgets = await getBudgets();
    double totalLimit = 0;
    double totalSpent = 0;
    int exceeded = 0;

    for (var budget in budgets) {
      totalLimit += (budget['monthly_limit'] as num).toDouble();
      totalSpent += (budget['current_spent'] as num).toDouble();
      if ((budget['current_spent'] as num) > (budget['monthly_limit'] as num)) {
        exceeded++;
      }
    }

    return {
      'total_limit': totalLimit,
      'total_spent': totalSpent,
      'exceeded_count': exceeded,
      'budgets': budgets,
    };
  }
}
