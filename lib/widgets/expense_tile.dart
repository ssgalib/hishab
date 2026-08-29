import 'package:flutter/material.dart';

import '../models/expense.dart';
import '../theme/app_theme.dart';
import '../utils/categories.dart';
import '../utils/format.dart';
import 'glass.dart';

/// Frosted expense row used on Home, History and search results.
class ExpenseTile extends StatelessWidget {
  const ExpenseTile({
    super.key,
    required this.expense,
    required this.onTap,
    this.showTime = true,
    this.showDate = true,
  });

  final Expense expense;
  final VoidCallback onTap;
  final bool showTime;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final info = categoryInfo(expense.category);
    final meta = [
      if (showTime) timeShort(expense.createdAt),
      if (showDate) dateShort(expense.createdAt),
    ].join(' · ');

    return GlassContainer(
      radius: 10,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: info.color.withValues(alpha: 0.10),
                ),
                child: Icon(info.icon, size: 21, color: info.ink),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        expense.item,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      meta,
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                fmtTaka(expense.amount),
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
