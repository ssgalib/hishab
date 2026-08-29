import 'package:flutter_test/flutter_test.dart';
import 'package:tracker/models/expense.dart';
import 'package:tracker/models/expense_parser.dart';
import 'package:tracker/utils/json_repair.dart';

void main() {
  group('JsonRepair', () {
    test('parses complete JSON', () {
      final m = JsonRepair.tryParse('{"item": "eggs", "amount": 50}');
      expect(m, isNotNull);
      expect(m!['item'], 'eggs');
    });

    test('parses JSON with trailing newline', () {
      final m = JsonRepair.tryParse('{"item": "eggs", "amount": 50}\n');
      expect(m, isNotNull);
    });

    test('repairs missing closing brace', () {
      final m = JsonRepair.tryParse(
        '{"item": "eggs", "quantity": "3", "amount": 50, "category": "food"\n',
      );
      expect(m, isNotNull);
      expect(m!['category'], 'food');
    });

    test('extracts JSON embedded in surrounding text', () {
      final m = JsonRepair.tryParse('Sure! Here: {"item": "rice", "amount": 30}');
      expect(m, isNotNull);
      expect(m!['item'], 'rice');
    });

    test('returns null for garbage', () {
      expect(JsonRepair.tryParse('I cannot help you with that.'), isNull);
    });

    test('returns null for empty', () {
      expect(JsonRepair.tryParse(''), isNull);
    });
  });

  group('ExpenseParser', () {
    test('parses complete model output', () {
      final e = ExpenseParser.fromRawJson(
        '{"item": "eggs", "quantity": "3", "amount": 50, "category": "food"}',
      );
      expect(e, isNotNull);
      expect(e!.item, 'eggs');
      expect(e.quantity, '3');
      expect(e.amount, 50);
      expect(e.category, 'food');
    });

    test('handles null quantity', () {
      final e = ExpenseParser.fromRawJson(
        '{"item": "bus", "quantity": null, "amount": 40, "category": "transport"}',
      );
      expect(e!.quantity, isNull);
    });

    test('defaults missing keys', () {
      final e = ExpenseParser.fromRawJson('{"item": "internet bill"}');
      expect(e!.amount, 0);
      expect(e.category, 'utilities');
    });

    test('moves a price misplaced in quantity into the amount', () {
      // Observed model output for "Bought Books for 300 taka".
      final e = ExpenseParser.fromRawJson(
        '{"item": "Books", "quantity": "300 taka"}',
      );
      expect(e, isNotNull);
      expect(e!.amount, 300);
      expect(e.quantity, isNull);
      expect(e.category, 'education');
      expect(ExpenseParser.needsReview(e), isFalse);
    });

    test('extracts price and keeps the real quantity', () {
      final e = ExpenseParser.fromRawJson(
        '{"item": "rice", "quantity": "5 kg 300 taka"}',
      );
      expect(e!.amount, 300);
      expect(e.quantity, '5 kg');
    });

    test('keeps plain quantities when the amount is missing', () {
      final e = ExpenseParser.fromRawJson(
        '{"item": "rice", "quantity": "2 kg"}',
      );
      expect(e!.amount, 0);
      expect(e.quantity, '2 kg');
      expect(ExpenseParser.needsReview(e), isTrue);
    });

    test('does not touch quantity when the amount is present', () {
      final e = ExpenseParser.fromRawJson(
        '{"item": "eggs", "quantity": "3", "amount": 50}',
      );
      expect(e!.amount, 50);
      expect(e.quantity, '3');
    });

    test('infers category from item when missing', () {
      final e = ExpenseParser.fromRawJson('{"item": "recharge"}');
      expect(e!.category, 'mobile');
    });

    test('repairs truncated JSON from the model', () {
      final e = ExpenseParser.fromRawJson(
        '{"item": "eggs", "quantity": "3", "amount": 50, "category": "food"',
      );
      expect(e, isNotNull);
      expect(e!.category, 'food');
    });

    test('returns null for unparseable output', () {
      expect(ExpenseParser.fromRawJson('garbage output here'), isNull);
    });

    test('needsReview flags missing amount and unknown item', () {
      Expense e(String item, int amount) => Expense(
            item: item,
            amount: amount,
            category: 'food',
            createdAt: DateTime(2026, 8, 29),
          );
      expect(ExpenseParser.needsReview(e('eggs', 50)), isFalse);
      expect(ExpenseParser.needsReview(e('eggs', 0)), isTrue);
      expect(ExpenseParser.needsReview(e('unknown', 50)), isTrue);
    });
  });
}
