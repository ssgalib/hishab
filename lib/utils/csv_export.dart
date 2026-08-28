import '../models/expense.dart';

/// Serializes expenses to RFC 4180-style CSV for backup/export.
String expensesToCsv(List<Expense> expenses) {
  final buffer = StringBuffer('date,item,quantity,amount,category\n');
  for (final e in expenses) {
    buffer.writeln([
      e.createdAt.toIso8601String(),
      _escape(e.item),
      _escape(e.quantity ?? ''),
      '${e.amount}',
      _escape(e.category),
    ].join(','));
  }
  return buffer.toString();
}

String _escape(String value) {
  if (value.contains(RegExp(r'[",\n\r]'))) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}
