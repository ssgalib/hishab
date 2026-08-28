import 'expense.dart';
import '../utils/json_repair.dart';

/// Converts raw model output into an [Expense], tolerating missing/invalid
/// fields. Returns null when the text cannot be parsed at all.
class ExpenseParser {
  static const validCategories = {
    'food',
    'transport',
    'utilities',
    'rent',
    'medicine',
    'education',
    'entertainment',
    'mobile',
  };

  static Expense? fromRawJson(String raw) {
    final map = JsonRepair.tryParse(raw);
    if (map == null) return null;

    final item = _cleanString(map['item']);
    final amountRaw = map['amount'];
    final amount = amountRaw is num ? amountRaw.toInt() : null;
    final quantity = _cleanNullableString(map['quantity']);
    var category = _cleanString(map['category']);
    if (category == null || !validCategories.contains(category)) {
      category = _inferCategory(item ?? '', quantity);
    }

    if (item == null && amount == null) return null;

    return Expense(
      item: item ?? 'unknown',
      quantity: quantity,
      amount: amount ?? 0,
      category: category ?? 'food',
      createdAt: DateTime.now(),
    );
  }

  /// Whether a parsed expense is too incomplete to save as-is: missing cost
  /// or unrecognized item. Such entries go to the edit sheet for review.
  static bool needsReview(Expense expense) =>
      expense.amount <= 0 || expense.item == 'unknown';

  static String? _cleanString(dynamic v) {
    if (v is String && v.trim().isNotEmpty) return v.trim();
    return null;
  }

  static String? _cleanNullableString(dynamic v) {
    final s = _cleanString(v);
    if (s == null || s.toLowerCase() == 'null') return null;
    return s;
  }

  static String? _inferCategory(String item, String? quantity) {
    const keywords = {
      'food': ['egg', 'rice', 'milk', 'oil', 'veg', 'fruit', 'meat', 'bread', 'potato', 'onion', 'chicken', 'fish'],
      'transport': ['bus', 'rickshaw', 'cng', 'uber', 'pathao', 'fare', 'ticket', 'petrol', 'fuel', 'train'],
      'utilities': ['electric', 'gas', 'water', 'internet', 'bill'],
      'medicine': ['medicine', 'drug', 'pharmacy', 'tablet', 'syrup'],
      'education': ['book', 'tuition', 'pen', 'pencil', 'course', 'exam'],
      'entertainment': ['movie', 'game', 'cinema'],
      'mobile': ['recharge', 'mobile', 'sim', 'data pack'],
    };
    final lower = '$item $quantity'.toLowerCase();
    for (final entry in keywords.entries) {
      if (entry.value.any(lower.contains)) return entry.key;
    }
    return 'food';
  }
}
