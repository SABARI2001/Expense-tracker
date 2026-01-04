import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/expense.dart';

class ExpenseService {
  final _client = Supabase.instance.client;

  Future<void> insertExpense(Expense expense) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    await _client.from('expenses').insert({
      'user_id': userId,
      'amount': expense.amount,
      'category': expense.category,
      'merchant': expense.merchant,
      'created_at': expense.date.toIso8601String(),
    });
  }

  Future<List<Expense>> fetchExpenses() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final data = await _client
        .from('expenses')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return data.map<Expense>((e) => Expense(
      amount: (e['amount'] as num).toDouble(),
      category: e['category'],
      merchant: e['merchant'],
      date: DateTime.parse(e['created_at']),
    )).toList();
  }

  Future<double> getTotalSpending() async {
    final expenses = await fetchExpenses();
    return expenses.fold<double>(0.0, (sum, expense) => sum + expense.amount);
  }
}
