import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/expense.dart';
import '../utils/categories.dart';

/// Modal bottom sheet for editing an existing [Expense].
///
/// Returns the updated [Expense] when saved, null when dismissed.
Future<Expense?> showEditExpenseSheet(BuildContext context, Expense expense) {
  return showModalBottomSheet<Expense>(
    context: context,
    isScrollControlled: true,
    builder: (_) => EditExpenseSheet(expense: expense),
  );
}

class EditExpenseSheet extends StatefulWidget {
  const EditExpenseSheet({super.key, required this.expense});

  final Expense expense;

  @override
  State<EditExpenseSheet> createState() => _EditExpenseSheetState();
}

class _EditExpenseSheetState extends State<EditExpenseSheet> {
  late final TextEditingController _item;
  late final TextEditingController _quantity;
  late final TextEditingController _amount;
  late String _category;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _item = TextEditingController(text: widget.expense.item);
    _quantity = TextEditingController(text: widget.expense.quantity ?? '');
    _amount = TextEditingController(text: '${widget.expense.amount}');
    _category = categories.any((c) => c.name == widget.expense.category)
        ? widget.expense.category
        : categories.first.name;
  }

  @override
  void dispose() {
    _item.dispose();
    _quantity.dispose();
    _amount.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      widget.expense.copyWith(
        item: _item.text.trim(),
        quantity: _quantity.text.trim().isEmpty ? null : _quantity.text.trim(),
        amount: int.parse(_amount.text.trim()),
        category: _category,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Edit expense',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            TextFormField(
              controller: _item,
              decoration: const InputDecoration(
                labelText: 'Item',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Enter an item' : null,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _quantity,
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      hintText: 'e.g. 2 kg',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _amount,
                    decoration: const InputDecoration(
                      labelText: 'Amount (৳)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Enter an amount' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownMenu<String>(
              expandedInsets: EdgeInsets.zero,
              initialSelection: _category,
              label: const Text('Category'),
              dropdownMenuEntries: [
                for (final c in categories)
                  DropdownMenuEntry(
                    value: c.name,
                    label: c.name[0].toUpperCase() + c.name.substring(1),
                    leadingIcon: Icon(c.icon, color: c.color, size: 20),
                  ),
              ],
              onSelected: (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
