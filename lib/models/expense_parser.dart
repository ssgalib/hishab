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
    int? amount = amountRaw is num ? amountRaw.toInt() : null;
    var quantity = _cleanNullableString(map['quantity']);
    var category = _cleanString(map['category']);

    // The model occasionally drops the price into `quantity` instead of
    // `amount` (e.g. {"quantity": "300 taka"}); move it back where it
    // belongs so the user isn't asked to re-enter a price they already said.
    if (amount == null || amount <= 0) {
      final price = _extractPriceFromQuantity(quantity);
      if (price != null) {
        amount = price.$1;
        quantity = price.$2;
      }
    }

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

  static final RegExp _priceWithCurrency = RegExp(
    r'(?:৳|taka|tk)\s*:?\s*(\d+)|(\d+)\s*(?:৳|taka|tk)',
    caseSensitive: false,
  );

  /// Finds a currency-cued price inside a quantity string, e.g.
  /// "300 taka" -> (300, null), "2 kg 500 taka" -> (500, "2 kg").
  /// Returns null when no price cue is present (plain quantities such as
  /// "2 kg" or "3" are never treated as prices).
  static (int, String?)? _extractPriceFromQuantity(String? quantity) {
    if (quantity == null) return null;
    final match = _priceWithCurrency.firstMatch(quantity);
    if (match == null) return null;
    final value = int.tryParse(match.group(1) ?? match.group(2) ?? '');
    if (value == null || value <= 0) return null;
    final remaining = quantity.replaceRange(match.start, match.end, ' ').trim();
    return (value, remaining.isEmpty ? null : remaining);
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
