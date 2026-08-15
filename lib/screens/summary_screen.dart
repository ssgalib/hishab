import 'package:flutter/material.dart';
import '../database/db_helper.dart';

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key, this.totalsLoader});

  /// Overridable loader for tests; defaults to the database.
  final Future<Map<String, int>> Function()? totalsLoader;

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  Map<String, int> _totals = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final totals = widget.totalsLoader != null
        ? await widget.totalsLoader!()
        : await DBHelper.getTotalByCategory();
    if (mounted) setState(() => _totals = totals);
  }

  @override
  Widget build(BuildContext context) {
    final maxVal = _totals.values.isEmpty
        ? 1
        : _totals.values.reduce((a, b) => a > b ? a : b);

    return Scaffold(
      appBar: AppBar(title: const Text('Summary')),
      body: _totals.isEmpty
          ? const Center(child: Text('No data yet'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: _totals.entries.map((e) {
                final fraction = e.value / maxVal;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(e.key,
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('${e.value} ৳'),
                        ],
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: fraction,
                        minHeight: 12,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}
