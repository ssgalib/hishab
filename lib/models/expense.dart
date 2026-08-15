class Expense {
  final int? id;
  final String item;
  final String? quantity;
  final int amount;
  final String category;
  final DateTime createdAt;

  const Expense({
    this.id,
    required this.item,
    this.quantity,
    required this.amount,
    required this.category,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'item': item,
    'quantity': quantity,
    'amount': amount,
    'category': category,
    'created_at': createdAt.toIso8601String(),
  };

  factory Expense.fromMap(Map<String, dynamic> map) => Expense(
    id: map['id'] as int?,
    item: map['item'] as String,
    quantity: map['quantity'] as String?,
    amount: map['amount'] as int,
    category: map['category'] as String,
    createdAt: DateTime.parse(map['created_at'] as String),
  );
}
