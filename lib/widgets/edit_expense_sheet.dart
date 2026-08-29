import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/expense.dart';
import '../theme/app_theme.dart';
import '../utils/categories.dart';
import '../utils/format.dart';
import 'glass.dart';

/// Modal sheet for creating, reviewing or editing an [Expense].
///
/// - [expense] null                  -> "New expense" (manual entry)
/// - [expense] with id               -> "Edit expense"
/// - [expense] without id + [heard]  -> voice review: "Confirm expense",
///   or "Almost there" when the parse is incomplete (missing amount).
Future<Expense?> showEditExpenseSheet(
  BuildContext context, [
  Expense? expense,
  String? heard,
]) {
  return showGlassSheet<Expense>(
    context: context,
    builder: (_) => EditExpenseSheet(
      expense: expense ??
          Expense(
            item: '',
            amount: 0,
            category: categories.first.name,
            createdAt: DateTime.now(),
          ),
      heard: heard,
    ),
  );
}

class EditExpenseSheet extends StatefulWidget {
  const EditExpenseSheet({super.key, required this.expense, this.heard});

  final Expense expense;
  final String? heard;

  bool get isCreating => expense.id == null;

  @override
  State<EditExpenseSheet> createState() => _EditExpenseSheetState();
}

class _EditExpenseSheetState extends State<EditExpenseSheet> {
  late final TextEditingController _item;
  late final TextEditingController _quantity;
  late final TextEditingController _amount;
  late DateTime _date;
  late String _category;
  late final bool _fromVoice;

  @override
  void initState() {
    super.initState();
    _fromVoice = widget.isCreating && widget.heard != null;
    _item = TextEditingController(text: widget.expense.item == 'unknown' ? '' : widget.expense.item);
    _quantity = TextEditingController(text: widget.expense.quantity ?? '');
    _amount = TextEditingController(
      text: widget.expense.amount == 0 ? '' : '${widget.expense.amount}',
    );
    _date = widget.expense.createdAt;
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

  bool get _itemMissing => _item.text.trim().isEmpty;

  /// Voice parse was incomplete: missing cost or unrecognized item.
  bool get _amountMissing => _fromVoice && widget.expense.amount <= 0;

  int get _parsedAmount => int.tryParse(_amount.text.trim()) ?? 0;

  bool get _canSave => !_itemMissing && _parsedAmount > 0;

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isAfter(now) ? now : _date,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _save() {
    if (!_canSave) return;
    Navigator.of(context).pop(
      widget.expense.copyWith(
        item: _item.text.trim(),
        quantity: _quantity.text.trim().isEmpty ? null : _quantity.text.trim(),
        amount: _parsedAmount,
        category: _category,
        createdAt: _date,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final (title, sub) = switch (this) {
      _ when widget.heard != null && _amountMissing => (
          'Almost there',
          'We got the item but missed the amount — fill it in.',
        ),
      _ when _fromVoice => (
          'Confirm expense',
          "Here's what we parsed from your voice.",
        ),
      _ when widget.isCreating => (
          'New expense',
          "Type the details — it'll be saved on this phone only.",
        ),
      _ => ('Edit expense', 'Update the details below.'),
    };

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHandle(),
            Text(title, style: const TextStyle(fontSize: 19)),
            const SizedBox(height: 4),
            Text(sub, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            const SizedBox(height: 14),
            if (widget.heard != null) ...[
              _HeardBox(heard: widget.heard!),
              const SizedBox(height: 16),
            ],
            const _FieldLabel('AMOUNT', required: true),
            const SizedBox(height: 8),
            _AmountInput(
              controller: _amount,
              autofocus: _amountMissing,
              onChanged: (_) => setState(() {}),
            ),
            if (_amountMissing) ...[
              const SizedBox(height: 6),
              const Row(
                children: [
                  Icon(Icons.info_outline, size: 13, color: AppColors.danger),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'No amount heard — add one to save.',
                      style: TextStyle(fontSize: 11, color: AppColors.danger),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            const _FieldLabel('ITEM'),
            const SizedBox(height: 8),
            _SheetInput(
              key: const Key('itemField'),
              controller: _item,
              hint: 'e.g. 3 eggs, rickshaw fare',
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            const _FieldLabel('QUANTITY'),
            const SizedBox(height: 8),
            _SheetInput(
              key: const Key('quantityField'),
              controller: _quantity,
              hint: 'e.g. 2 kg',
            ),
            const SizedBox(height: 16),
            const _FieldLabel('CATEGORY'),
            const SizedBox(height: 8),
            _CategoryGrid(
              selected: _category,
              onSelected: (v) => setState(() => _category = v),
            ),
            const SizedBox(height: 16),
            const _FieldLabel('DATE'),
            const SizedBox(height: 8),
            _DateRow(date: _date, onTap: _pickDate),
            const SizedBox(height: 22),
            _SaveButton(enabled: _canSave, amount: _parsedAmount, onTap: _save),
          ],
        ),
      ),
    );
  }
}

class _HeardBox extends StatelessWidget {
  const _HeardBox({required this.heard});

  final String heard;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      radius: 14,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 3),
            child: Icon(Icons.mic_none, size: 15, color: AppColors.accentInk),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'HEARD FROM YOUR VOICE',
                  style: TextStyle(fontSize: 9, letterSpacing: 0.9, color: AppColors.muted),
                ),
                const SizedBox(height: 3),
                Text(
                  '“$heard”',
                  style: const TextStyle(fontSize: 13, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text, {this.required = false});

  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: text),
        if (required)
          const TextSpan(text: ' *', style: TextStyle(color: AppColors.danger)),
      ]),
      style: const TextStyle(
        fontSize: 10,
        letterSpacing: 0.9,
        color: AppColors.muted,
      ),
    );
  }
}

class _AmountInput extends StatelessWidget {
  const _AmountInput({
    required this.controller,
    required this.onChanged,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.glassFillStrong,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Row(
        children: [
          const Text(
            '৳',
            style: TextStyle(fontSize: 26, color: AppColors.accentInk),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              key: const Key('amountField'),
              controller: controller,
              autofocus: autofocus,
              onChanged: onChanged,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 30, letterSpacing: -0.6),
              decoration: const InputDecoration(
                hintText: '0',
                hintStyle: TextStyle(color: AppColors.muted),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetInput extends StatelessWidget {
  const _SheetInput({
    super.key,
    required this.controller,
    required this.hint,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textCapitalization: textCapitalization,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.muted),
        filled: true,
        fillColor: AppColors.glassFillStrong,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: _border(),
        focusedBorder: _border(color: AppColors.accent),
        border: _border(),
      ),
    );
  }

  OutlineInputBorder _border({Color? color}) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color ?? AppColors.border, width: 1.5),
      );
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.05,
      children: [
        for (final c in categories)
          _CategoryChip(
            info: c,
            selected: c.name == selected,
            onTap: () => onSelected(c.name),
          ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.info,
    required this.selected,
    required this.onTap,
  });

  final CategoryInfo info;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? info.ink : AppColors.muted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? info.color.withValues(alpha: 0.6)
                : AppColors.border,
            width: 1.5,
          ),
          color: selected
              ? info.color.withValues(alpha: 0.16)
              : AppColors.glassFillStrong,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(info.icon, size: 20, color: fg),
            const SizedBox(height: 6),
            Text(
              info.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: fg),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({required this.date, required this.onTap});

  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.glassFillStrong,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 18, color: AppColors.muted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(dateRowLabel(date), style: const TextStyle(fontSize: 13)),
            ),
            const Icon(Icons.expand_more, size: 18, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.enabled,
    required this.amount,
    required this.onTap,
  });

  final bool enabled;
  final int amount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        constraints: const BoxConstraints(minHeight: 52),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: enabled ? AppColors.accent : AppColors.fg.withValues(alpha: 0.08),
          boxShadow: enabled
              ? const [
                  BoxShadow(
                    color: AppColors.accentShadow,
                    offset: Offset(0, 4),
                    blurRadius: 14,
                  ),
                ]
              : null,
        ),
        child: Text(
          enabled ? 'Save ${fmtTaka(amount)}' : 'Save expense',
          style: TextStyle(
            fontSize: 14,
            color: enabled ? AppColors.fg : AppColors.muted,
          ),
        ),
      ),
    );
  }
}
