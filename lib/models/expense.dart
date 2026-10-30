class Expense {
  final int? id;
  final String name;
  final int amount;
  final String category;
  final DateTime date;

  Expense({
    this.id,
    required this.name,
    required this.amount,
    required this.category,
    required this.date,
  });

  // Convert Expense to Map for SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'category': category,
      'date': date.toIso8601String(),
    };
  }

  // Convert SQLite data to Expense
  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as int?,
      name: map['name'] as String,
      amount: map['amount'] as int,
      category: map['category'] as String,
      date: DateTime.parse(map['date'] as String),
    );
  }
}