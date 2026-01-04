import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/expense.dart';
import '../services/expense_service.dart';
import 'add_expense_screen.dart';
import 'insights_screen.dart';
import 'admin_screen.dart';
import 'expenses_screen.dart';
import 'profile_screen.dart';
import 'budgets_screen.dart';
import '../widgets/expense_card.dart';
import '../core/session_guard.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdmin();
  }

  Future<void> _checkAdmin() async {
    final isAdmin = await SessionGuard.isAdmin();
    setState(() => _isAdmin = isAdmin);
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      const _HomeTab(),
      const ExpensesScreen(),
      const BudgetsScreen(),
      const InsightsScreen(),
      if (_isAdmin) const AdminScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Expenses',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Budgets',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.insights),
            label: 'Insights',
          ),
          if (_isAdmin)
            const BottomNavigationBarItem(
              icon: Icon(Icons.admin_panel_settings),
              label: 'Admin',
            ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddExpenseScreen()),
                );
                if (result == true) {
                  setState(() {}); // Refresh
                }
              },
              backgroundColor: Colors.blueAccent,
              child: const Icon(Icons.add, size: 32),
            )
          : null,
    );
  }
}

class _HomeTab extends StatefulWidget {
  const _HomeTab();

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> with AutomaticKeepAliveClientMixin {
  final _expenseService = ExpenseService();
  late Future<List<Expense>> _expensesFuture;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _refreshExpenses();
  }

  void _refreshExpenses() {
    setState(() {
      _expensesFuture = _expenseService.fetchExpenses();
    });
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _getUserName() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user?.userMetadata?['full_name'] != null) {
      return user!.userMetadata!['full_name'] as String;
    }
    final email = user?.email ?? '';
    return email.split('@').first;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_getGreeting()},',
              style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.normal),
            ),
            Text(
              _getUserName(),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ],
        ),
      ),
      body: FutureBuilder<List<Expense>>(
        future: _expensesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          
          final expenses = snapshot.data ?? [];
          final totalExpenses = expenses.fold(0.0, (sum, e) => sum + e.amount);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary Cards
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildBalanceCard(totalExpenses),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildExpenseCard(totalExpenses),
                    ),
                  ],
                ),
                
                const SizedBox(height: 32),
                
                // Recent Transactions Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Recent Transactions',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: const Text('View All', style: TextStyle(color: Colors.blueAccent)),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Transaction List
                expenses.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40.0),
                          child: Column(
                            children: [
                              Icon(Icons.receipt_long, size: 64, color: Colors.grey[300]),
                              const SizedBox(height: 16),
                              Text(
                                'No expenses yet',
                                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Tap + to add your first expense',
                                style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: expenses.take(5).length,
                        itemBuilder: (context, index) {
                          return ExpenseCard(expense: expenses[index]);
                        },
                      ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBalanceCard(double total) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 8),
              const Text(
                'Total Balance',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '\$${total.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseCard(double total) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.arrow_upward, color: Colors.red[400], size: 20),
          ),
          const SizedBox(height: 12),
          const Text(
            'Expenses',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            '-\$${total.toStringAsFixed(0)}',
            style: TextStyle(
              color: Colors.red[600],
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
