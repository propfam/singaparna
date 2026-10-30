import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../database/_helper.dart';
import '../models/expense.dart';

class ExpenseChartPage extends StatefulWidget {
  const ExpenseChartPage({super.key});

  @override
  State<ExpenseChartPage> createState() => _ExpenseChartPageState();
}

class _ExpenseChartPageState extends State<ExpenseChartPage> {
  List<Expense> _expenses = [];
  bool _isLoading = true;

  int _selectedMonthRange = 12;

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    try {
      final expenses = await DatabaseHelper.instance.getExpenses();

      if (!mounted) return;

      setState(() {
        _expenses = expenses;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat grafik: $e')),
      );
    }
  }

  Map<String, int> get _categoryTotals {
    final totals = <String, int>{};

    for (final expense in _expenses) {
      totals.update(
        expense.category,
        (value) => value + expense.amount,
        ifAbsent: () => expense.amount,
      );
    }

    return totals;
  }

  Map<String, int> get _monthlyTotals {
    final totals = <String, int>{};

    final now = DateTime.now();

    for (final expense in _expenses) {
      final expenseMonth = DateTime(
        expense.date.year,
        expense.date.month,
      );

      if (_selectedMonthRange != 0) {
        final startMonth = DateTime(
          now.year,
          now.month - _selectedMonthRange + 1,
        );

        if (expenseMonth.isBefore(startMonth)) {
          continue;
        }
      }

      final month =
          '${expense.date.year}-${expense.date.month.toString().padLeft(2, '0')}';

      totals.update(
        month,
        (value) => value + expense.amount,
        ifAbsent: () => expense.amount,
      );
    }

    final sortedEntries = totals.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Map.fromEntries(sortedEntries);
  }

  String _monthLabel(String value) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];

    final month = int.parse(value.split('-')[1]);
    return '${months[month - 1]} ${value.split('-')[0]}';
  }

  String _formatCurrency(num value) {
    final rounded = value.round();
    final text = rounded.toString();
    final result = StringBuffer();

    for (var i = 0; i < text.length; i++) {
      result.write(text[i]);

      final remaining = text.length - i - 1;
      if (remaining > 0 && remaining % 3 == 0) {
        result.write('.');
      }
    }

    return 'Rp$result';
  }

  String _formatAxisCurrency(double value) {
    if (value >= 1000000) {
      final amount = value / 1000000;
      return 'Rp${amount == amount.roundToDouble() ? amount.toStringAsFixed(0) : amount.toStringAsFixed(1)}jt';
    }

    if (value >= 1000) {
      return 'Rp${(value / 1000).round()}rb';
    }

    return 'Rp${value.round()}';
  }

  Widget _buildMonthlyChart() {
    final entries = _monthlyTotals.entries.toList();

    if (entries.isEmpty) {
      return const _EmptyChart(message: 'Belum ada data pengeluaran.');
    }

    final maxAmount = entries
        .map((entry) => entry.value)
        .reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 260,
      child: BarChart(
        BarChartData(
          maxY: maxAmount == 0 ? 100 : maxAmount * 1.2,
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final entry = entries[group.x.toInt()];
                return BarTooltipItem(
                  '${_monthLabel(entry.key)}\n${_formatCurrency(rod.toY)}',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            // Detailed left axis
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 65,
                getTitlesWidget: (value, meta) {
                  return Text(
                    _formatAxisCurrency(value),
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();

                  if (index < 0 || index >= entries.length) {
                    return const SizedBox.shrink();
                  }

                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _monthLabel(entries[index].key),
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < entries.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: entries[i].value.toDouble(),
                    color: const Color(0xFF2E7D32),
                    width: entries.length > 8 ? 12 : 22,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(5),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChart() {
    final entries = _categoryTotals.entries.toList();

    if (entries.isEmpty) {
      return const _EmptyChart(message: 'Belum ada data pengeluaran.');
    }

    final colors = [
      const Color(0xFF2E7D32),
      const Color(0xFF66BB6A),
      const Color(0xFFFFB74D),
      const Color(0xFF42A5F5),
      const Color(0xFFAB47BC),
      const Color(0xFFEF5350),
    ];

    final total = entries.fold<int>(
      0,
      (sum, entry) => sum + entry.value,
    );

    return Column(
      children: [
        SizedBox(
          height: 240,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 3,
                  centerSpaceRadius: 62,
                  sections: [
                    for (var i = 0; i < entries.length; i++)
                      PieChartSectionData(
                        value: entries[i].value.toDouble(),
                        color: colors[i % colors.length],
                        radius: 55,
                        title: total == 0
                            ? ''
                            : '${(entries[i].value / total * 100).round()}%',
                        titleStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
              ),

              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _formatCurrency(total),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B1F1B),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < entries.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: colors[i % colors.length],
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(entries[i].key)),
                Text(
                  _formatCurrency(entries[i].value),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Grafik Pengeluaran'),
        backgroundColor: const Color(0xFFF5F7F2),
      ),
      backgroundColor: const Color(0xFFF5F7F2),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadExpenses,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _ChartCard(
                    title: 'Pengeluaran Bulanan',
                    subtitle: 'Perbandingan pengeluaran setiap bulan',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<int>(
                          initialValue: _selectedMonthRange,
                          decoration: const InputDecoration(
                            labelText: 'Periode Grafik',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 6,
                              child: Text('6 Bulan Terakhir'),
                            ),
                            DropdownMenuItem(
                              value: 12,
                              child: Text('12 Bulan Terakhir'),
                            ),
                            DropdownMenuItem(
                              value: 0,
                              child: Text('Semua Data'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedMonthRange = value;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 20),
                        _buildMonthlyChart(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _ChartCard(
                    title: 'Pengeluaran per Kategori',
                    subtitle: 'Proporsi total pengeluaran tiap kategori',
                    child: _buildCategoryChart(),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}

class _EmptyChart extends StatelessWidget {
  final String message;

  const _EmptyChart({required this.message});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      child: Center(
        child: Text(
          message,
          style: const TextStyle(color: Colors.black54),
        ),
      ),
    );
  }
}
