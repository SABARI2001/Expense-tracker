import 'package:flutter/material.dart';
import '../services/budget_service.dart';

class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  final _budgetService = BudgetService();
  late Future<Map<String, dynamic>> _budgetSummaryFuture;

  @override
  void initState() {
    super.initState();
    _refreshBudgets();
  }

  void _refreshBudgets() {
    setState(() {
      _budgetSummaryFuture = _budgetService.getBudgetSummary();
    });
  }

  void _showAddBudgetDialog() {
    final categoryController = TextEditingController();
    final limitController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Budget'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: categoryController,
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: limitController,
              decoration: const InputDecoration(labelText: 'Monthly Limit'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _budgetService.createBudget(
                  categoryController.text,
                  double.parse(limitController.text),
                );
                if (mounted) {
                  Navigator.pop(context);
                  _refreshBudgets();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Budget created!')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text(
          'Budgets',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _budgetSummaryFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final summary = snapshot.data!;
          final budgets = summary['budgets'] as List<Map<String, dynamic>>;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Budget',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '\$${summary['total_limit'].toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Spent', style: TextStyle(color: Colors.white70, fontSize: 12)),
                              Text(
                                '\$${summary['total_spent'].toStringAsFixed(2)}',
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Exceeded', style: TextStyle(color: Colors.white70, fontSize: 12)),
                              Text(
                                '${summary['exceeded_count']} categories',
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                const Text(
                  'Category Budgets',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                if (budgets.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Column(
                        children: [
                          Icon(Icons.account_balance_wallet, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text('No budgets set', style: TextStyle(color: Colors.grey[600])),
                          const SizedBox(height: 8),
                          Text('Tap + to create your first budget', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                        ],
                      ),
                    ),
                  )
                else
                  ...budgets.map((budget) => _buildBudgetCard(budget)),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddBudgetDialog,
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBudgetCard(Map<String, dynamic> budget) {
    final limit = (budget['monthly_limit'] as num).toDouble();
    final spent = (budget['current_spent'] as num).toDouble();
    final percentage = (spent / limit * 100).clamp(0, 100);
    final isExceeded = spent > limit;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isExceeded ? Border.all(color: Colors.red, width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                budget['category'],
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (isExceeded)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'EXCEEDED',
                    style: TextStyle(color: Colors.red[700], fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '\$${spent.toStringAsFixed(2)} / \$${limit.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              Text(
                '${percentage.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isExceeded ? Colors.red : Colors.blueAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percentage / 100,
              minHeight: 8,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                isExceeded ? Colors.red : Colors.blueAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
