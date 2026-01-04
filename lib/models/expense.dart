class Expense {
  final double amount;
  final String category;
  final String merchant;
  final DateTime date;

  Expense({
    required this.amount,
    required this.category,
    required this.merchant,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
    'amount': amount,
    'category': category,
    'merchant': merchant,
    'created_at': date.toIso8601String(),
  };
}
